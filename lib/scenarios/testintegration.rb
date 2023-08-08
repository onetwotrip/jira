module Scenarios
  require 'jira-ruby'
  ##
  # TestIntegration scenario
  class TestIntegration
    def run
      jira_issue = SimpleConfig.jira.issue

      LOGGER.info "Starting for #{jira_issue}"

      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(jira_issue)

      puts issue.to_json

      fields = issue.fields
      issue_links = fields['issuelinks']

      new_issues = []
      updated_issues = {}

      issue_links.each do |link|
        inward_issue = link['inwardIssue']
        outward_issue = link['outwardIssue']
        issue_name = inward_issue ? inward_issue['key'] : outward_issue['key']
        id = inward_issue ? inward_issue['id'] : outward_issue['id']

        nestedIssue = jira.Issue.find(id)
        nested_issue_links = nestedIssue.fields['issuelinks']

        nested_keys_blocks = []
        nested_keys_relates = []
        nested_keys_cloners = []
        nested_keys_deployed = []
        nested_keys_duplicated = []
        nested_keys_inheritanced = []
        
        nested_object = {}

        nested_issue_links.each do |nested_link|
          nested_inward_issue = nested_link['inwardIssue']
          nested_outward_issue = nested_link['outwardIssue']
          nested_key = nested_inward_issue ? nested_inward_issue['key'] : nested_outward_issue['key']

          type = nested_link['type']['name']

          case type
          when 'Blocks'
            nested_keys_blocks.push("https://onetwotripdev.atlassian.net/browse/#{nested_key}")
            nested_object[:blocks] = nested_keys_blocks
          when 'Relates'
            nested_keys_relates.push("https://onetwotripdev.atlassian.net/browse/#{nested_key}")
            nested_object[:relates] = nested_keys_relates
          when 'Cloners'
            nested_keys_cloners.push("https://onetwotripdev.atlassian.net/browse/#{nested_key}")
            nested_object[:cloners] = nested_keys_cloners
          when 'Deployed'
            nested_keys_deployed.push("https://onetwotripdev.atlassian.net/browse/#{nested_key}")
            nested_object[:deployed] = nested_keys_deployed 
          when 'Duplicate'
            nested_keys_deployed.push("https://onetwotripdev.atlassian.net/browse/#{nested_key}")
            nested_object[:duplicated] = nested_keys_duplicated
          when 'Inheritance'
            nested_keys_inheritanced.push("https://onetwotripdev.atlassian.net/browse/#{nested_key}")
            nested_object[:inheritanced] = nested_keys_inheritanced
          end

          updated_issues = { "https://onetwotripdev.atlassian.net/browse/#{issue_name}": nested_object }
        end

        new_issues.push(updated_issues)
      end

      request_body = {
        "version": 1,
        "type": 'doc',
        "content": [
          {
            "type": 'paragraph',
            "content": transform_content(new_issues),
          }],
      }.to_json

      url = "#{ENV['JIRA_SITE']}/rest/internal/3/issue/#{jira_issue}/description"

      LOGGER.info "PUT #{url}"

      RestClient::Request.execute(
        method: :put,
        url: url,
        payload: request_body,
        headers: { content_type: :json },
        user: SimpleConfig.jira[:username],
        password: SimpleConfig.jira[:password]
      )
    end

    def transform_content(array)
      content = []

      array.each do |hash|
        content << { type: 'text', text: '=============================================' }
        content << { type: 'hardBreak' }

        hash.each do |key, value|
          content << { type: 'inlineCard', attrs: { url: key.to_s } }
          content << { type: 'text', text: '  =>' }
          content << { type: 'hardBreak' }

          value.each do |key, value|
            if value.is_a?(Array)
              content << { type: 'text', text: key.to_s + ':' }
              content << { type: 'hardBreak' }

              value.each do |item|
                content << { type: 'inlineCard', attrs: { url: item } }
                content << { type: 'text', text: ' ' }
                content << { type: 'hardBreak' }
              end
            else
              content << { type: 'text', text: key.to_s + ':' }
              content << { type: 'hardBreak' }
              content << { type: 'inlineCard', attrs: { url: value.to_s } }
              content << { type: 'text', text: ' ' }
              content << { type: 'hardBreak' }
            end
          end
        end
      end

      content << { type: 'text', text: '=============================================' }
      content
    end
  end
end
