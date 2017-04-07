module Scenarios
  ##
  # ReviewIssue scenario
  class ReviewIssue
    def run
      LOGGER.info "Starting #{self.class.name} for #{SimpleConfig.jira.issue}"
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)

      puts issue.status.name
      exit
      # Check issie status
      LOGGER.error "Issue '#{issue.key}' doesn't have 'Code review' status" unless issue.status.name == 'Code Review'

      # Check builds status
      Ott::CheckBranchesBuildStatuses.run(issue)

      # Post comment
      issue.post_comment LOGGER.history_comment(EnhancedLogger::WARN)

      # Send stricts
      Ott::StrictControl.run(issue)
    end
  end
end
