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

      LOGGER.info "Issue already has labels: #{labels} - I will add all new one to current" unless labels.empty?

      issue.api_pullrequests.each do |br|
        LOGGER.info("Repo: #{br.repo_slug}")
        labels << br.repo_slug
      end

      unless ENV['LABELS'].nil?
        LOGGER.info "Found some additional labels: #{ENV['LABELS']} I will add them to issue #{issue.key}"
        additional_label = ENV['LABELS']
        labels << additional_label
      end

      LOGGER.info "Add labels: #{labels.uniq} to issue #{issue.key}"
      issue.save(fields: { labels: labels.uniq })
    end
  end
end
