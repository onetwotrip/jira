module Scenarios
  ##
  # RollbackRelease scenario
  class RollbackRelease
    def run
      LOGGER.info "Starting RollbackRelease for #{SimpleConfig.jira.issue}"
      jira    = JIRA::Client.new SimpleConfig.jira.to_h
      release = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
      release.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Запущен откат релиза (!)
        #{ENV['BUILD_URL']} 
        Ожидайте сообщение о завершении
      {panel}
      BODY
      begin
        release.rollback
        release.linked_issues('deployes').each do |issue|
          trans = 'Not merged'
          if issue.has_transition?(trans)
            LOGGER.info "Rollback issue '#{issue.key}': transition to '#{trans}'"
            issue.transition trans
          else
            LOGGER.warn "Rollback issue '#{issue.key}': transition '#{trans}' not found"
          end
        end
      rescue StandardError => e
        release.post_comment <<-BODY
        {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
         Не удалось откатить релиз (x)
         Подробности в логе таски #{ENV['BUILD_URL']} 
        {panel}
        BODY
        LOGGER.error "Не удалось откатить релиз, ошибка: #{e.message}, трейс:\n\t#{e.backtrace.join("\n\t")}"
        exit(1)
      end
      # Write message in release ticket
      release.post_comment <<-BODY
        {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
          Откат релиза завершен (/)
        {panel}
      BODY
    end
  end
end
