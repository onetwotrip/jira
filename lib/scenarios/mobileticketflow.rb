module Scenarios
  ##
  # Automate merge ticket after change jira status from Test Ready -> Merge Ready
  class MobileTicketFlow
    def with(instance, &block)
      instance.instance_eval(&block)
      instance
    end

    def run
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      # noinspection RubyArgCount
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info("Start work with #{issue.key}")
      is_error = false
      is_empty = false

      blocked_by_issues = issue.linked_issues('is blocked by')

      if blocked_by_issues.empty?
        LOGGER.warn("Doesn't found any block issues")
      else
        LOGGER.warn("Found #{blocked_by_issues.count} issues that blocks current issue. Start to check PR")
        blocked_by_issues.each do |i|
          pullrequests = i.pullrequests(SimpleConfig.git.to_h)
                          .filter_by_status('OPEN')
                          .filter_by_source_url(i.key)
          # Product ticket with merged PR -> pullrequest object doesn't contain them at all
          if !pullrequests.empty?
            LOGGER.error("#{i.key}: found not merged PR for product branch")
            issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
          Нашел блокирующий тикет: #{i.key} у которого не смержен PR. Прежде чем мержить эту задачу, нужно закончить с #{i.key}
      {panel}
            BODY
            issue.transition 'Merge Fail'
            exit 1
          else
            LOGGER.info("#{i.key}: ALL PR is merged. Go next...")
          end
        end
       end

      pullrequests = issue.pullrequests(SimpleConfig.git.to_h)
                          .filter_by_status('OPEN')
                          .filter_by_source_url(SimpleConfig.jira.issue)

      if pullrequests.empty?
        issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        В тикете нет открытых PR! Мержить нечего {noformat}¯\\_(ツ)_/¯{noformat}
      {panel}
        BODY
        is_empty = true
      end

      # rubocop:disable Metrics/BlockLength
      pullrequests.each do |pr|
        src_branch = pr.pr['source']['branch']
        dst_branch = pr.pr['destination']['branch']
        pr_url = pr.pr['url']

        # Check is destination is master
        if dst_branch.eql?('master')
          LOGGER.error("Found branch #{src_branch} with PR to 'master'!!!")
          issue.post_comment <<-BODY
      {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
          Мерж ветки *#{src_branch}* не прошел, т.к. у нее PR в *мастер*! Не надо так делать!
      {panel}
          BODY
          next
        end
        unless blocked_by_issues.empty?
          unless dst_branch.eql?('develop')
            LOGGER.error("#{issue.key}: Ticket has blocked by issues, but found branch #{src_branch} with PR not to 'develop'!!!")
            issue.post_comment <<-BODY
      {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
          Мерж ветки *#{src_branch}* не прошел, т.к. у текущей задачи есть blocked by задачи, поэтому такие задачи могут иметь PR только в develop
      {panel}
            BODY
            issue.transition 'Merge Fail'
            exit 1
          end
        end
        LOGGER.info("Push PR from #{src_branch} to '#{dst_branch}")
        begin
          local_repo = pr.simple_repo
          with local_repo do
            merge_pullrequest(pr.pr['id'])
          end
        rescue StandardError => e
          is_error = true
          puts e.message.red
          issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  Не удалось замержить PR: #{pr_url}
                  *Причина:* #{e.message}
              {panel}
          BODY
          issue.transition 'Merge Fail'
          next
        end
      end

      if is_error
        exit(1)
      else
        exit if is_empty
        issue.post_comment <<-BODY
            {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#10B924|bgColor=#F1F3F1}
              Все валидные PR смержены!
            {panel}
        BODY
      end
    end
  end
end
