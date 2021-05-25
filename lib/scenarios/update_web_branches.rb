module Scenarios
  ##
  # Try to merge master branch in ticket's branches
  class UpdateWebBranches
    def find_by_filter(issue, filter)
      issue.jql("filter=#{filter}", max_results: 100)
    rescue JIRA::HTTPError => jira_error
      error_message = jira_error.response['body_exists'] ? jira_error.message : jira_error.response.body
      LOGGER.error "Error in JIRA with the search by filter #{filter}: #{error_message}"
      []
    end

    def with(instance, &block)
      instance.instance_eval(&block)
      instance
    end

    def update_issue(issue)
      pullrequests = issue.pullrequests(SimpleConfig.git.to_h).filter_by_status('OPEN')
      LOGGER.info "Found #{pullrequests.prs.count} pullrequests".green
      pullrequests.each do |pr| # rubocop:disable Metrics/BlockLength
        next unless pr.pr['destination']['branch'].include? 'master'
        begin
          pr_repo = git_repo(pr.pr['destination']['url'])
          # Prepare repo
          pr_repo.pull('origin', 'master')
          branch_name = pr.pr['source']['branch']
          LOGGER.info "Try to update PR: #{branch_name}".green
          with pr_repo do
            checkout branch_name
            pull('origin', branch_name)
            pull('origin', 'master')
            push(pr_repo.remote('origin'), branch_name)
          end
          LOGGER.info "Successful update:  #{branch_name}"
        rescue StandardError => e
          if e.message.include?('Merge conflict')
            LOGGER.error "Update PR failed. Reason: Merge Conflict. LOG: #{e.message}"
            issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  Не удалось подмержить master в PR: #{pr.pr['url']}
                  *Причина:* Merge conflict
                  LOG: #{e.message}
              {panel}
            BODY
          else
            LOGGER.error "Update PR failed. Reason: #{e.message}"
            issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  *Не удалось подмержить master в PR*: #{pr.pr['url']}
                  *Причина:* #{e.message}
              {panel}
            BODY
          end
          issue.transition 'Reopened'
          next
        end
      end
    end

    def run
      update_filter_config = ENV['UPDATE_FILTER']
      unless update_filter_config
        LOGGER.error("UPDATE_FILTER config not found")
        exit(1)
      end

      update_filter_config = JSON.parse(update_filter_config)
      # Get all tickets
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      # noinspection RubyArgCount
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
      LOGGER.info("Start work after #{issue.key} was merged")

      project_name = issue.fields['project']['key']

      LOGGER.info "Take #{project_name} filter"
      filter = update_filter_config[project_name]
      unless filter
        LOGGER.warn("Can't find task filter for project #{project_name}. Pls, check config")
        exit 127
      end

      LOGGER.info "Try to find all tasks from filter #{filter}".green
      issues = find_by_filter(jira.Issue, filter)
      LOGGER.info "Found #{issues.count} issues".green
      count_max = issues.count
      counter   = 1

      issues.each do |i|
        LOGGER.info "Work with #{i.key} (#{counter}/#{count_max})"
        update_issue(i)
        counter += 1
      end
    end
  end
end
