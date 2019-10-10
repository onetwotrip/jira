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

    def update_issue(issue)
      # Получить ветки
      is_success = false
      pullrequests = issue.pullrequests(SimpleConfig.git.to_h).filter_by_status('OPEN')
      pullrequests.each do |pr|
        next unless pr.pr['destination']['branch'].include? 'develop'
        begin
        pr_repo = pr.repo
        branch_name = pr.pr['source']['branch']
        with pr_repo do
          checkout branch_name
          pull('origin', branch_name)
          pull('origin', 'develop')
          push(pr_repo.remote('origin'), branch_name)
        end
        LOGGER.info "Successful update:  #{branch_name}"
        is_success = true
        rescue StandardError => e
          LOGGER.error "Не удалось подтянуть develop, ошибка: #{e.message}, трейс:\n\t#{e.backtrace.join("\n\t")}"
          if e.message.include?('Merge conflict')
            issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  Не удалось подмержить develop в PR: #{pr.pr['url']}
                  *Причина:* Merge conflict
              {panel}
            BODY
          else
            issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  *Не удалось подмержить develop в PR*: #{pr.pr['url']}
                  *Причина:* #{e.message}
              {panel}
            BODY
          end
          issue.transition 'Reopen'
          is_success = false
          next
        end
      end
      is_success
    end

    def run
      adr_filter = 30_361
      # Get all tickets
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      # noinspection RubyArgCount
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info("Start work after #{issue.key} was merged")
      project_name = issue.fields['project']['key']

      abort('IOS ticket was merged, so i will skip this task. Only ADR project supports this feature') if project_name.include?('IOS')

      LOGGER.info "Try to find all tasks from filter #{adr_filter}".green
      issues = find_by_filter(jira.Issue, adr_filter)
      LOGGER.info "Found #{issues.count} issues".green
      count_max = issues.count
      counter = 1
      issues.each do |issue|
        LOGGER.info "Work with #{issue.key} (#{counter}/#{count_max})"
        is_success = update_issue(issue)
        if is_success
          LOGGER.info "Successful update:  #{issue.key}"
        else
          LOGGER.error "Error update:  #{issue.key}"
        end
        counter += 1
      end
    end
  end
end
