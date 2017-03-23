module Scenarios
  ##
  # RollbackRelease scenario
  class RollbackRelease
    def run
      LOGGER.info "Starting RollbackRelease for #{SimpleConfig.jira.issue}"
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      release = jira.Issue.find(SimpleConfig.jira.issue)
      return unless release.status.name != 'Open'
      release.rollback(do_trans: true)
      release.linked_issues('deployes').each(&:rollback)
    end
  end
end
