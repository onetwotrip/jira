module Scenarios
  ##
  # TestIntegration scenario
  class TestIntegration
    def run
      LOGGER.info "Starting for #{SimpleConfig.jira.issue}"

      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)

      issues = []

      puts issue.fields.issuelinks

      issue = issue.to_json
      issue_links = issue.fields[:issuelinks]

      puts issue_links

      issue_links.each do |link|
        inward_issue = link[:inwardIssue]
        key = inward_issue[:key]
        id = inward_issue[:id]

        nestedIssue = jira.Issue.find(id)

        nestedIssue = nestedIssue.to_json
        nested_issue_links = nestedIssue[:fields][:issuelinks]

        nested_id = 0

        nested_issue_links.each do |nested_link|
          nested_inward_issue = nested_link[:inwardIssue]
          nested_id = nested_inward_issue[:id]
        end

        object = { key: key, id: nested_id }
        issues << object
      end

      puts issues.to_json

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
