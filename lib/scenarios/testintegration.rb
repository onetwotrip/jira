module Scenarios
  ##
  # TestIntegration scenario
  class TestIntegration
    def run
      LOGGER.info "Starting for #{SimpleConfig.jira.issue}"

      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issueLink = JIRA::Resource::Issuelink.new(jira, SimpleConfig.jira.issue)
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      # issue = jira.Issuelink.find(SimpleConfig.jira.issue)

      puts issueLink
      puts issue


      # issue.post_comment <<-BODY
      # {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
      #   Тестовое сообщение(!)
      #   #{ENV['BUILD_URL']}
      #   Ожидайте сообщение о завершении
      # {panel}
      # BODY
    end
  end
end
