module Scenarios
  ##
  # PostactionRelease scenario
  class PostactionRelease
    def run
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      # noinspection RubyArgCount
      issue = jira.Issue.find(SimpleConfig.jira.issue)

      is_error = false

      pullrequests = issue.pullrequests(SimpleConfig.git.to_h)
                          .filter_by_status('OPEN')
                          .filter_by_source_url(SimpleConfig.jira.issue)

      unless pullrequests.valid?
        issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  Не удалось замержить PR
                  *Причина:* Нет валидных PR(Статус: Open и с номером задачи в названии)
              {panel}

        BODY
        exit(1)
      end

      pullrequests.each do |pr|
        # Checkout repo
        puts "Clone/Open with #{pr.dst} branch #{pr.dst.branch} and merge #{pr.src.branch} and push".green
        begin
          pr.repo.push('origin', pr.pr['destination']['branch'])
        rescue Git::GitExecuteError => e
          is_error = true
          puts e.message.red
          if e.message.include?('Merge conflict')
            issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  Не удалось замержить PR: #{pr.pr['url']}
                  *Причина:* Merge conflict
              {panel}

            BODY
          else
            issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  Не удалось замержить PR: #{pr.pr['url']}
                  *Причина:* #{e.message}
              {panel}

            BODY
          end
          next
        end
      end

      issue.linked_issues('deployes').each do |subissue|
        # Transition to DONE
        subissue.transition 'To master' if subissue.get_transition_by_name 'To master'
      end

      exit(1) if is_error
    end
  end
end
