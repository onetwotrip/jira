module Scenarios
  ##
  # PostactionRelease scenario
  class PostactionRelease
    def with(instance, &block)
      instance.instance_eval(&block)
      instance
    end

    def run
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      # noinspection RubyArgCount
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Запущено подмерживание релизных веток и закрытие тикетов(!)
        #{ENV['BUILD_URL']} 
        Ожидайте сообщение о завершении
      {panel}
      BODY
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
        issue.transition 'Undo code merge'
        exit(1)
      end

      pullrequests.each do |pr|
        # Checkout repo
        puts "Merge PR: #{pr.pr['url']}".green
        begin
          local_repo = pr.repo
          with local_repo do
            merge_pullrequest(pr.pr['id'])
          end
        rescue StandardError => e
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

      if is_error
        LOGGER.error "Some PR didn't merge"
        issue.transition 'Undo code merge'
        exit(1)
      else
        LOGGER.info "Everything fine. Try to move tickets to 'DONE' status"
        issue.linked_issues('deployes').each do |subissue|
          # Transition to DONE
          subissue.transition 'To master' if subissue.get_transition_by_name 'To master'
        end
      end
      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Мерж релизных веток - завершен. Перевод задач - завершен (/)
      {panel}
      BODY
    end
  end
end
