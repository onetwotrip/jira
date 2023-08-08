module Scenarios
  ##
  # TestIntegration scenario
  class TestIntegration
    def run
      LOGGER.info "Starting for #{SimpleConfig.jira.issue}"

      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)

      issue = issue.to_json

      issueLinks = issue['fields']['issuelinks']

      puts issueLinks

      puts "====================="

      issues = []

      issueLinks.each do |i|
        nestedIssueId = issueLinks[i]['inwardIssue']['id']

        puts nestedIssueId

        puts "====================="

        nestedIssue = jira.Issue.find(nestedIssueId)
        nestedIssueLinks = nestedIssue.fields['issuelinks']

        updatedIssue = {
          nestedIssueId: nestedIssueLinks
        }

        issues.push(updatedIssue)
      end

      puts issues

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
