module Scenarios
  ##
  # ReviewRelease scenario
  class ReviewRelease
    def run
      LOGGER.info "Starting #{self.class.name} for #{SimpleConfig.jira.issue}"
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)

      # Check issie status
      LOGGER.error "Issue '#{issue.key}' doesn't have 'Code review' status" unless issue.status.name == 'Code review'

      # Check branches name
      issue.branches.each do |branch|
        branch_path = "#{branch.repo_owner}/#{branch.repo_slug}/#{branch.name}"
        unless branch.name.match "^#{issue.key}-pre"
          LOGGER.error "Incorrect branch name: #{branch_path}"
        end
      end

      # Check pullrequests name
      issue.api_pullrequests.select { |pr| pr.state == 'OPEN' }.each do |pr|
        LOGGER.info "Check PR: #{pr.title}"
        unless pr.title.match "^#{issue.key}"
          LOGGER.error "Incorrect PullRequest name: #{pr.title}"
        end
      end

      # Check builds status
      Ott::CheckBranchesBuildStatuses.run(issue)

      # Post comment
      comment = LOGGER.history_comment(EnhancedLogger::WARN)
      issue.post_comment comment.empty? ? 'OK' : comment

      # Send stricts
      Ott::StrictControl.run(issue)
    end
  end
end
