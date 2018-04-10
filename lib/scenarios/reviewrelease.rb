module Scenarios
  ##
  # ReviewRelease scenario
  class ReviewRelease
    def run
      LOGGER.info "Starting #{self.class.name} for #{SimpleConfig.jira.issue}"
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)

      # Check issie status
      LOGGER.error "Issue '#{issue.key}' doesn't have 'Code review' status" unless issue.status.name == 'Code Review'

      # Check branches name
      issue.branches.each do |branch|
        branch_path = "#{branch.repo_owner}/#{branch.repo_slug}/#{branch.name}"
        LOGGER.error "Incorrect branch name: #{branch_path}" unless branch.name.match "^#{issue.key}-pre"
      end

      # Check pullrequests name
      issue.api_pullrequests.select { |pr| pr.state == 'OPEN' }.each do |pr|
        LOGGER.info "Check PR: #{pr.title}"
        LOGGER.error "Incorrect PullRequest name: #{pr.title}" unless pr.title.match "^#{issue.key}"
      end

      # Check builds status
      Ott::CheckBranchesBuildStatuses.run(issue)

      # Post comment
      comment = LOGGER.history_comment(EnhancedLogger::WARN)
      if comment.empty?
        LOGGER.info 'Review is OK. No errors'
        issue.post_comment LOGGER.history_comment(EnhancedLogger::INFO)
      else
        issue.post_comment comment
        issue.transition 'WTF'
      end

      # Send stricts
      Ott::StrictControl.run(issue)
    end
  end
end
