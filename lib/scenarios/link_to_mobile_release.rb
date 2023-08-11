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

      client = JIRA::Client.new SimpleConfig.jira.to_h
      issue = client.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s

      issue = client.Issue.find(SimpleConfig.jira.issue)
      # puts issue.to_json
      # puts issue.fields['customfield_12166']['value'].class
      apps = issue.fields['customfield_12166']['value']
      issue_links = issue.fields['issuelinks']
      # puts issue_links
      puts apps

      deployes_issues = []

      issue_links.each do |item|
        if item['type']['outward'] == 'deployes'
          deployes_issues.append(item['outwardIssue']['key'])
        end
      end

      puts deployes_issues

      arr_tiket_and_apps = []

      deployes_issues.each do |find_issues_tiket|
        issue = client.Issue.find(find_issues_tiket)
        puts issue.fields['customfield_12207'][0]['value']
        # puts client.Issue.find(find_issues_tiket).fields['customfield_12207']['value']
        # arr_tiket_and_apps.append({number: find_issues_tiket, apps: client.Issue.find(find_issues_tiket).fields['customfield_12207']['value']})
      end

      puts arr_tiket_and_apps
      # deployes_issues.each do |issues_app|
      #   find = client.Issue.find(issues_app)
      #
      #   puts find.to_json
      # end

      # if apps.length > 1
      #   # берем следующий элемент
      # end

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