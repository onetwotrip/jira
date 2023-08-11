module Scenarios
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

      issue = client.Issue.find(SimpleConfig.jira.issue)
      puts issue

      ## 1. Получаем список АППС
      message = 'Получаем список АППС'
      issue.post_comment <<-BODY
          {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
            #{message} (x)
          {panel}
      BODY
      LOGGER.error message
      raise 'Assemble field is empty'
    end
  end
end