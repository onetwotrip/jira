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

      filter_config = JSON.parse(params[:filter])
      project_name  = params[:project]
      release_name  = params[:name].upcase
      release_issue = params[:issue]

      # Check project exist in filter_config
      if filter_config[project_name].nil?
        LOGGER.error "I can't work with project '#{project_name.upcase}'. Pls, contact administrator to feedback"
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
        LOGGER.error "I don't find release filter for project '#{project_name.upcase}' and release_type: #{release_type}"
        raise 'Release_filter not found'
      end

      LOGGER.info "Release filter: #{release_filter}"

      client = JIRA::Client.new SimpleConfig.jira.to_h

      issues = release_filter && find_by_filter(client.Issue, release_filter)

      release_labels = []
      issues.each do |issue|
        issue.link(release_issue)
        issue.related['branches'].each do |branch|
          release_labels << branch['repository']['name'].to_s
        end
      end

      release_labels.uniq!

      LOGGER.info "Add labels: #{release_labels} to release #{release_name}"
      release_issue = client.Issue.find(release_issue)
      release_issue.save(fields: { labels: release_labels })
      release_issue.fetch

      LOGGER.info "Storing '#{release_issue}' to file, to refresh buildname in Jenkins"
      Ott::Helpers.export_to_file(release_issue, 'release_name.txt')
    end
  end
end
