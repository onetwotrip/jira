module Scenarios
  ##
  # ReviewIssue scenario
  class ReviewIssue
    def run
      LOGGER.info "Starting review #{SimpleConfig.jira.issue}"
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
      # Check PR names
      Ott::CheckPullRequests.run(issue)
      # Check builds status
      Ott::CheckBuildStatuses.for_open_pull_request(issue)
    end
  end
end
