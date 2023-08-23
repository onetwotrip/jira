module Scenarios
  require 'jira-ruby'

  class AddLinkedIssuesDependenciesToDescription
    def run
      @jira_issue = SimpleConfig.jira.issue

      LOGGER.info "Start adding linked issues dependencies for main issue #{@jira_issue}"

      jira = JIRA::Client.new SimpleConfig.jira.to_h
      client = JIRA::Client.new(options)
      main_issue = jira.Issue.find(@jira_issue)

      def get_all_linked_issues(issue, issues=Set.new)
        linked_issues = issue.linked_issues
        linked_issues.each do |linked_issue|
          unless issues.include?(linked_issue.key)
            issues << linked_issue.key
            get_all_linked_issues(linked_issue, issues)
          end
        end
        issues
      end

      linked_issues = get_all_linked_issues(main_issue);

      def link_issues(client, issue1_key, issue2_key, link_type)
        link = client.IssueLink.build

        link.save(
          {
            type: { name: link_type },
            inwardIssue: { key: issue1_key },
            outwardIssue: { key: issue2_key }
          }
        )
      end

      linked_issues.each do |issue_key|
        link_issues(client, issue_key, 'ISSUE_KEY', 'Relates')
      end
    end
  end
end
