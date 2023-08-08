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

      formatted_string = transform_hash(issues)

      request_body = { "version": 1, "type": 'doc', "content": [{ "type": 'paragraph', "content": [{ "type": 'text', "text": formatted_string.to_s }] }] }

      LOGGER.info "PUT rest/internal/3/issue/#{SimpleConfig.jira.issue}/description"

      RestClient::Request.execute(
        method: :put,
        url: "#{ENV['JIRA_SITE']}/rest/internal/3/issue/#{SimpleConfig.jira.issue}/description",
        user: SimpleConfig.jira[:username],
        password: SimpleConfig.jira[:password],
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

    def transform_hash(hash)
      result = ''

      hash.each do |key, value|
        result += "#{key} =>\n"

        value.each do |k, v|
          if v.is_a?(Array)
            result += "#{k} => #{v.join(', ')}\n"
          else
            result += "#{k} => #{v}\n"
          end
        end
      end
      result
    end
  end
end
