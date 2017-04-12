module Scenarios
  ##
  # RollbackRelease scenario
  class RollbackRelease
    def run
      LOGGER.info "Starting RollbackRelease for #{SimpleConfig.jira.issue}"
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      release = jira.Issue.find(SimpleConfig.jira.issue)
      release.rollback
      release.linked_issues('deployes').each do |issue|
        trans = 'Not merged'
        if issue.has_transition?(trans)
          LOGGER.info "Rollback issue '#{issue.key}': transition to '#{trans}'"
          issue.transition trans
        else
          LOGGER.warn "Rollback issue '#{issue.key}': transition '#{trans}' not found"
        end
      end
    end
  end
end
