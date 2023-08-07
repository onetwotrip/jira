module Scenarios
  ##
  # TestIntegration scenario
  class TestIntegration
    def run
      LOGGER.info "Starting #{self.class.name} for #{SimpleConfig.jira.issue}"
      jira  = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
      LOGGER.info 'Get all labels'
      labels = issue.labels

      LOGGER.info "Issue already has labels: #{labels} - I will add all new one to current" unless labels.empty?

      issue.api_pullrequests.each do |br|
        LOGGER.info("Repo: #{br.repo_slug}")
        labels << br.repo_slug
      end

      unless ENV['LABELS'].nil?
        LOGGER.info "Found some additional labels: #{ENV['LABELS']} - I will add them to issue #{issue.key}"
        ENV['LABELS'].sub(' ', '').split(',').each do |it|
          labels << it
        end
      end

      LOGGER.info "Add labels: #{labels.uniq} to issue #{issue.key}"
      issue.save(fields: { labels: labels.uniq })
    end
  end
end
