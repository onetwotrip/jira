module Scenarios
  ##
  # Check issue has merged special PR
  class MergeChecker
    def run
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
      # Prepare taboo_repos depend from jira state
      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Запущена проверка тикета на наличие не запаблишенных компонентов(!)
        #{ENV['BUILD_URL']} 
        Ожидайте сообщение о завершении
      {panel}
      BODY
      taboo_repos = case issue.status.name
                      when 'Test ready'
                        %w[front-components]
                      when 'Merge ready'
                        %w[back-components front-components]
                      else
                        %w[]
                    end
      LOGGER.info "Starting check PR for #{taboo_repos} repos"
      # Check Does ticket from FC project with not PUBLISHED status exist
      begin
        all_issues = []
        issue.issuelinks.each do |i|
          all_issues.append(i.outwardIssue) if i.outwardIssue
          all_issues.append(i.inwardIssue) if i.inwardIssue
        end
        not_merged_component = all_issues.select { |i| i.key.include?('FC-') && !i.status.name.include?('Published') }

        unless not_merged_component.empty?
          error_msg = "Find issue: #{not_merged_component.first.key}  without PUBLISHED status. Need transfer current issue to 'WAIT COMPONENT PUBLISH' status"
          LOGGER.error error_msg
          issue.post_comment error_msg
          issue.transition 'Wait Component Publish'

          LOGGER.warn "Also need transfer #{not_merged_component.first.key} in status 'NEED PUBLISH'"
          not_merged_component.first.post_comment "Linked issue #{issue.key} ready for release and wait while this issue going to be published"
          not_merged_component.first.transition 'Need Publish'
          raise 'Some errors found. See log above'
        end

        issue.development.branches.each do |branch|
          LOGGER.info "Work with #{branch.repo}:#{branch.url}"
          next unless taboo_repos.include? branch.repo

          LOGGER.warn "Found repo from #{taboo_repos}. Check PR status"
          if %w[OPEN].include? branch.pr_status
            LOGGER.error 'Branch has open PR. Need to be merged before go next'
            issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  В задаче есть одна из веток #{taboo_repos}, которая должна быть замержена, прежде чем задача перейдет в Merge Ready статус.
                  Обратитесь к техлиду.
              {panel}
            BODY
            issue.transition 'Need Components Merge'
            exit 1
          else
            LOGGER.info "Branch: #{branch.url} has PR status: #{branch.pr_status}"
            issue.post_comment <<-BODY
              {panel:title=CodeOwners checker!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#b8b8e8|bgColor=#d2d2d2}
                  Все компоненты замержены(/)
              {panel}
            BODY
          end
        end
      rescue StandardError => e
        issue.post_comment <<-BODY
        {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
         Не выполнить проверку тикета (x)
         Подробности в логе таски #{ENV['BUILD_URL']}
        {panel}
        BODY
        LOGGER.error "Не выполнить проверку тикета, ошибка: #{e.message}, трейс:\n\t#{e.backtrace.join("\n\t")}"
        exit(1)
      end
    end
  end
end
