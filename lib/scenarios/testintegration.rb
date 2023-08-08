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
        issue_name = inward_issue ? inward_issue['key'] : outward_issue['key']
        id = inward_issue ? inward_issue['id'] : outward_issue['id']

        nestedIssue = jira.Issue.find(id)
        nested_issue_links = nestedIssue.fields['issuelinks']

        nested_keys_blocks = []
        nested_keys_relates = []

        nested_object = {}

        nested_issue_links.each do |nested_link|
          # puts nested_link
          # puts "===================="

          nested_inward_issue = nested_link['inwardIssue']
          nested_outward_issue = nested_link['outwardIssue']
          type = nested_link['type']['name']

          nested_key = nested_inward_issue ? nested_inward_issue['key'] : nested_outward_issue['key']

          if type == 'Blocks'
            nested_keys_blocks.push(nested_key)

            object = {
              type: type,
              urls: nested_keys_blocks
            }

            nested_object[:blocks] = object
          elsif type == 'Relates'
            nested_keys_relates.push(nested_key)

            object = {
              type: type,
              urls: nested_keys_relates
            }

            nested_object[:relates] = object
          end
        end

        object = { issue: "https://onetwotripdev.atlassian.net/browse/#{issue_name}", nested_issues: nested_object }

        issues << object
      end

      puts issues.to_json

      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Внимание, зависимость задач (!)
        #{issues.to_json}
      {panel}
      BODY
    end
  end
end
