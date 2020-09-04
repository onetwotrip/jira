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

      pullrequests.each do |pr| # rubocop:disable Metrics/BlockLength
        src_branch = pr.pr['source']['branch']
        dst_branch = pr.pr['destination']['branch']
        pr_url     = pr.pr['url']

        # Check is destination is master
        if dst_branch.eql?('master')
          LOGGER.error("Found branch #{src_branch} with PR to 'master'!!!")
          issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
          Мерж ветки *#{src_branch}* не прошел, т.к. у нее PR в *мастер*! Не надо так делать!
      {panel}
          BODY
          next
        end
        LOGGER.info("Push PR from #{src_branch} to '#{dst_branch}")
        begin
          local_repo = pr.simple_repo
          with local_repo do
            merge_pullrequest(pr.pr['id'])
          end
        rescue StandardError => e
          is_error = true
          puts e.response.red
          issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  Не удалось замержить PR: #{pr_url}
                  *Причина:* #{e.response}
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
