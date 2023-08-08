module Scenarios
  ##
  # TestIntegration scenario
  class TestIntegration
    def run
      LOGGER.info "Starting for #{SimpleConfig.jira.issue}"

      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)

      issues = []

      fields = issue.fields
      issue_links = fields['issuelinks']

      issue_links.each do |link|
        inward_issue = link['inwardIssue']
        outward_issue = link['outwardIssue']
        key = inward_issue ? inward_issue['key'] : outward_issue['key']
        id = inward_issue ? inward_issue['id'] : outward_issue['id']

        nestedIssue = jira.Issue.find(id)
        nested_issue_links = nestedIssue.fields['issuelinks']

        nested_name = 0
        nested_key = 0

        nested_issue_links.each do |nested_link|
          nested_inward_issue = nested_link['inwardIssue']
          nested_outward_issue = nested_link['outwardIssue']
          nested_name = nested_link['type']['name']

          # nested_id = nested_inward_issue ? nested_inward_issue['id'] : nested_outward_issue['id']
          nested_key = nested_inward_issue ? nested_inward_issue['key'] : nested_outward_issue['key']
        end

        object = { key: key, nested_issues: {
          nested_name: nested_name,
          nested_key: nested_key,
        } }

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
