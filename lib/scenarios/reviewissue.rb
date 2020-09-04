module Scenarios
  ##
  # ReviewIssue scenario
  class ReviewIssue
    def run
      LOGGER.info "Starting #{self.class.name} for #{SimpleConfig.jira.issue}"
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)

      # Check issie status
      LOGGER.error "Issue '#{issue.key}' doesn't have 'Code review' status" unless issue.status.name == 'Code Review'

      # Check builds status
      Ott::CheckBranchesBuildStatuses.run(issue)
      Ott::CheckPullRequests.run(issue)

      # Post comment
      comment = LOGGER.history_comment(EnhancedLogger::ERROR)
      if comment.empty?
        LOGGER.info 'Review is OK. No errors'
        issue.post_comment LOGGER.history_comment(EnhancedLogger::INFO)
      else
        issue.post_comment comment
        issue.transition 'WTF'
      end
    end
  end
end
