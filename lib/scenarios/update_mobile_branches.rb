module Scenarios
  ##
  # Try to merge develop branch in ticket's branches
  class UpdateMobileBranches
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

    def run
      adr_filter = 30_361
      ios_filter = 30_421
      # Get all tickets
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      # noinspection RubyArgCount
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      update_issue(issue)
      LOGGER.info("Start work after #{issue.key} was merged")
      project_name = issue.fields['project']['key']

      # abort('IOS ticket was merged, so i will skip this task. Only ADR project supports this feature') if project_name.include?('IOS')

      filter = case project_name
                 when 'ADR'
                   LOGGER.info "Took ADR filter: #{adr_filter}"
                   adr_filter
                 when 'IOS'
                   LOGGER.info "Took IOS filter: #{ios_filter}"
                   ios_filter
                 else
                   abort('Only IOS or ADR projects support this cool feature, so i will skip this task')
               end

      LOGGER.info "Try to find all tasks from filter #{filter}".green
      issues = find_by_filter(jira.Issue, filter)
      LOGGER.info "Found #{issues.count} issues".green
      count_max = issues.count
      counter = 1

      issues.each do |i|
        LOGGER.info "Work with #{i.key} (#{counter}/#{count_max})"
        unless i.fields['fixVersions'].empty?
          LOGGER.warn "Issue #{i.key} contains fixVersions, so this is release ticket and i will skip update branch"
          next
        end
        update_issue(i)
        counter += 1
      end
    end

    def update_issue(issue)
      pullrequests = issue.pullrequests(SimpleConfig.git.to_h).filter_by_status('OPEN')
      LOGGER.info "Found #{pullrequests.prs.count} pullrequests".green
      pullrequests.each do |pr| # rubocop:disable Metrics/BlockLength
        unless pr.pr['destination']['branch'].include? 'develop'
          LOGGER.warn "Found PR from #{pr.pr['source']['branch']} to #{pr.pr['destination']['branch']}. SKIP!"
          next
        end
        LOGGER.info "Found PR from #{pr.pr['source']['branch']} to #{pr.pr['destination']['branch']}. ok!".green
        begin
          pr_repo = git_repo(pr.pr['destination']['url'])
          # Prepare repo
          pr_repo.pull('origin', 'develop')
          branch_name = pr.pr['source']['branch']
          LOGGER.info "Try to update PR: #{branch_name}".green
          with pr_repo do
            checkout branch_name
            pull('origin', branch_name)
            pull('origin', 'develop')
            push(pr_repo.remote('origin'), branch_name)
          end
          LOGGER.info "Successful update:  #{branch_name}"
        rescue StandardError => e
          if e.message.include?('Merge conflict')
            LOGGER.error "Update PR failed. Reason: Merge Conflict. LOG: #{e.message}"
            issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  Не удалось подмержить develop в PR: #{pr.pr['url']}
                  *Причина:* Merge conflict
                  LOG: #{e.message}
              {panel}
            BODY
          else
            LOGGER.error "Update PR failed. Reason: #{e.message}"
            issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  *Не удалось подмержить develop в PR*: #{pr.pr['url']}
                  *Причина:* #{e.message}
              {panel}
            BODY
          end
          issue.transition 'Conflicts'
          next
        end
      end
    end
  end
end
