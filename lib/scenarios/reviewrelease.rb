module Scenarios
  ##
  # ReviewRelease scenario
  class ReviewRelease
    def run
      LOGGER.info "Starting #{self.class.name} for #{SimpleConfig.jira.issue}"
      jira  = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)

      # Check pullrequests name
      issue.api_pullrequests.select { |pr| pr.state == 'OPEN' }.each do |pr|
        LOGGER.info "Check PR: #{pr.title}"
        LOGGER.error "Incorrect PullRequest name: #{pr.title}" unless pr.title.match "^#{issue.key}"
      end

      # Check builds status
      Ott::CheckBuildStatuses.for_all_branches(issue)
    end
  end
end
