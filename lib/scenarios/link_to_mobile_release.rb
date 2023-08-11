module Scenarios
  ##
  # Link tickets to release issue
  class LinkToMobileRelease
    def find_by_filter(issue, filter)
      issue.jql("filter=#{filter}", max_results: 100)
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
      issue = client.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s

      issue = client.Issue.find(SimpleConfig.jira.issue)
      puts issue
      puts issue.fields['customfield_12166']

      # ## 1. Получаем список АППС
      # message = 'Получаем список АППС'
      # issue.post_comment <<-BODY
      #     {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
      #       #{message} (x)
      #     {panel}
      # BODY
      # LOGGER.error message
      # raise 'Assemble field is empty'
    end
  end
end