module Scenarios
  ##
  # SetLabelIssue scenario
  class SetLabelIssue
    def run
      LOGGER.info "Starting #{self.class.name} for #{SimpleConfig.jira.issue}"
      jira  = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)

      LOGGER.info 'Get all labels'
      labels = issue.labels
      issue.api_pullrequests.each do |br|
        LOGGER.info("Repo: #{br.repo_slug}")
        labels << br.repo_slug
      end

      LOGGER.info "Add labels: #{labels.uniq} to issue #{issue.key}"
      issue.save(fields: { labels: labels.uniq })
    end
  end
end
