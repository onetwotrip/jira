module Scenarios
  ##
  # ReviewIssue scenario
  class ReviewIssue
    def run
      LOGGER.info "Starting review #{SimpleConfig.jira.issue}"
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
      if Ott::Helpers.mobile_project?(issue.key)
        LOGGER.info 'Check mobile issue'
        # get assemble field
        # if assemble empty - error msg and Return to In Progress
        # else check if assemble == b2b_ott
        # if not - exit
        # else get all open PR
        # if empty - error msg exit
        # else check if destination is android_b2b repo
        # if it is - go next, else error -> In Progress
      else
        LOGGER.info 'Check web issue'
        # Check PR names
        Ott::CheckPullRequests.run(issue)
        # Check builds status
        Ott::CheckBuildStatuses.for_open_pull_request(issue)
      end
    end
  end
end
