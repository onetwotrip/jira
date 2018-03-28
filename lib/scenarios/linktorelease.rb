module Scenarios
  ##
  # Link tickets to release issue
  class LinkToRelease
    def find_by_filter(issue, filter)
      issue.jql("filter=#{filter}")
    rescue JIRA::HTTPError => jira_error
      error_message = jira_error.response['body_exists'] ? jira_error.message : jira_error.response.body
      LOGGER.error "Error in JIRA with the search by filter #{filter}: #{error_message}"
      []
    end

    def run
      params = SimpleConfig.release

      unless params
        LOGGER.error 'No Release params in ENV'
        exit
      end

      filter_config = JSON.parse(ENV['RELEASE_FILTER'])
      client = JIRA::Client.new SimpleConfig.jira.to_h
      release_issue = client.Issue.find(SimpleConfig.jira.issue)

      project_name  = release_issue.fields['project']['key']
      release_name  = release_issue.fields['summary'].upcase
      release_issue_number = release_issue.key

      # Check project exist in filter_config
      if filter_config[project_name].nil?
        message = "I can't work with project '#{project_name.upcase}'. Pls, contact administrator to feedback"
        release_issue.post_comment(message)
        LOGGER.error message
        raise 'Project not found'
      end

      LOGGER.info "Linking tickets to release '#{release_name}'"

      # Check release type
      release_type = if %w(_BE_ _BE BE_ BE).any? { |str| release_name.include?(str) }
                       'backend'
                     elsif %w(_FE_ _FE FE_ FE).any? { |str| release_name.include?(str) }
                       'frontend'
                     else
                       'common'
                     end

      LOGGER.info "Release type: #{release_type}"
      release_filter = filter_config[project_name][release_type]
      # Check release filter
      if release_filter.nil? || release_filter.empty?
        message = "I don't find release filter for jira project: '#{project_name.upcase}' and release_type: #{release_type}"
        release_issue.post_comment(message)
        LOGGER.error message
        raise 'Release_filter not found'
      end

      LOGGER.info "Release filter: #{release_filter}"

      issues = release_filter && find_by_filter(client.Issue, release_filter)

      # Message about count of release candidate issues
      release_issue.post_comment("Тикетов будет прилинковано: #{issues.count}")

      release_labels = []
      issues.each do |issue|
        issue.link(release_issue_number)
        issue.related['branches'].each do |branch|
          release_labels << branch['repository']['name'].to_s
        end
      end

      release_labels.uniq!

      LOGGER.info "Add labels: #{release_labels} to release #{release_name}"
      release_issue.save(fields: { labels: release_labels })
      release_issue.fetch

      # Message about done
      release_issue.post_comment('Формирование релиза закончено')
    end
  end
end
