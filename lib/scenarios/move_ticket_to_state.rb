module Scenarios
  ##
  # CreateRelease scenario
  class MoveTicketToState
    def run
      jira  = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info "Try to move ticket #{issue.key} from state '#{issue.status.name}' to '#{ENV['STATE']}'"
      issue.transition ENV['STATE']
    end
  end
end
