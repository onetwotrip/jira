module Scenarios
  ##
  # CreateRelease scenario
  class CheckReleaseExist
    # :nocov:
    def run
      LOGGER.info 'Check if SERVICE_NAME is set'
      if ENV['SERVICE_NAME'].nil?
        LOGGER.warn "Couldn't find any service name in ENV[SERVICE_NAME]. Skip this step"
        exit
      end

      LOGGER.info "Start check if release exist for #{ENV['SERVICE_NAME']}"

      client = JIRA::Client.new SimpleConfig.jira.to_h

      filter            = "type = Release and labels = #{ENV['SERVICE_NAME']} AND status in(Open,'Build Release','Build Failed',Testing,Passed,Staging,Production)" # rubocop:disable Metrics/LineLength</code>
      existing_releases = client.Issue.jql(filter, max_results: 100)

      unless existing_releases.empty?
        LOGGER.warn "Found #{existing_releases.count} release(s) for Service: #{ENV['SERVICE_NAME']} in work. Before continue they are should be in DONE status" # rubocop:disable Metrics/LineLength</code>
        Ott::Helpers.export_to_file("SLACK_URL=''", 'release_properties')
        exit(127)
      end

      LOGGER.info "There is no any release in work for service: #{ENV['SERVICE_NAME']}"
    rescue JIRA::HTTPError => jira_error
      error_message = jira_error.response['body_exists'] ? jira_error.message : jira_error.response.body
      LOGGER.error "Error in JIRA with the search exist release #{error_message}"
    end
  end
end
