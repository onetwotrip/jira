module Scenarios
  ##
  # TestIntegration scenario
  class TestIntegration
    def run
      LOGGER.info "Starting for #{SimpleConfig.jira.issue}"

      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      ## create loop for all linked issues
      # issue = jira.Issue.find('RND-123'

      issueLinks = issue.fields['issuelinks']

      nestedIssueId = issueLinks[0]['inwardIssue']['id']

      puts nestedIssueId

      puts '=============================================='

      nestedIssue = jira.Issue.find(nestedIssueId)

      puts nestedIssue.to_json


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
