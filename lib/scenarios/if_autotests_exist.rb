module Scenarios
  # Check if avia_api_rspec has autotests for service under testing
  class IfAutotestsExist

    def run
      LOGGER.info "Starting #{self.class.name} for #{SimpleConfig.jira.issue}"
      jira  = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s

      repo_with_autotests = ENV['REPO_WITH_AUTOTESTS']
      white_list = ENV['REPO_WHITE_LIST']
      LOGGER.info("REPO_WITH_AUTOTESTS: #{repo_with_autotests}")
      LOGGER.info("REPO_WHITE_LIST: #{white_list}")

      result = []
      issue.branches.each do |branch|
        result << branch.repo_slug
      end
      LOGGER.info("Find repos: #{result}")

      result.each do |repo|
        if repo_with_autotests.include? repo
          LOGGER.info "Repo: #{repo} has api autotests"
          next

        elsif white_list.include? repo
          LOGGER.warn "Repo: #{repo} in whitelist, i will skip it"
          next
        else
          LOGGER.warn "Repo: #{repo} doesn't have api autotests and can't be tested"
          exit 127
        end
      end
    end
  end

end