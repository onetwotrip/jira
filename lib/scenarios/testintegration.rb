module Scenarios
  require 'jira-ruby'
  ##
  # TestIntegration scenario
  class TestIntegration
    def run
      LOGGER.info "Starting for #{SimpleConfig.jira.issue}"

      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)

      fields = issue.fields
      issue_links = fields['issuelinks']

      issue_name = ''
      nested_object = {}

      issue_links.each do |link|
        inward_issue = link['inwardIssue']
        outward_issue = link['outwardIssue']
        issue_name = inward_issue ? inward_issue['key'] : outward_issue['key']
        id = inward_issue ? inward_issue['id'] : outward_issue['id']

        nestedIssue = jira.Issue.find(id)
        nested_issue_links = nestedIssue.fields['issuelinks']

        nested_keys_blocks = []
        nested_keys_relates = []

        nested_issue_links.each do |nested_link|
          nested_inward_issue = nested_link['inwardIssue']
          nested_outward_issue = nested_link['outwardIssue']
          nested_key = nested_inward_issue ? nested_inward_issue['key'] : nested_outward_issue['key']

          type = nested_link['type']['name']

          if type == 'Blocks'
            nested_keys_blocks.push("https://onetwotripdev.atlassian.net/browse/#{nested_key}")
            nested_object[:blocks] = nested_keys_blocks
          elsif type == 'Relates'
            nested_keys_relates.push("https://onetwotripdev.atlassian.net/browse/#{nested_key}")
            nested_object[:relates] = nested_keys_relates
          end
        end
      end

      issues = { "https://onetwotripdev.atlassian.net/browse/#{issue_name}": nested_object }

      request_body = { "version": 1, "type": 'doc', "content": [{ "type": 'paragraph', "content": [{ "type": 'text', "text": issues.to_s }] }] }

      LOGGER.info "PUT rest/api/2/issue/#{issue_name}/description"

      RestClient::Request.execute(
        method: :put,
        url: create_endpoint("rest/api/2/issue/#{issue_name}/description").to_s,
        user: opts[:username],
        password: opts[:token],
        payload: request_body.to_json,
        headers: { content_type: :json }
      )

      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Внимание, зависимость задач (!)
        {noformat}
          #{JSON.pretty_generate(issues)}
        {noformat}
      {panel}
      BODY
    end
  end
end
