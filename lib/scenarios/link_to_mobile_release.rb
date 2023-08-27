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

      # Получаем данные тикета
      client = JIRA::Client.new SimpleConfig.jira.to_h
      issue  = client.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s

      # Уточняем какой тип проекта будет проверятся Андроид или IOS
      if issue.key[0..2].eql?('IOS') || issue.key[0..2].eql?('ADR')
        project = issue.key.include?('IOS') ? 'ios' : 'android'
        # Получаем значения поля apps из релиза
        # apps = issue.fields['customfield_12166']['value']
        apps = issue.fields['customfield_12208']['value']

        # Проверяем есть ли релизы AND/IOS с такими значениями и не закрытые
        # Производим поиск открытых релизов
        created_releases = client.Issue.jql(
          %(project = #{project} and issuetype = Release and status not in (Rejected, Done) and "App[Dropdown]" = #{apps} and issue != #{issue.key}), max_results: 100)

        # if created_releases == []
        if created_releases == []
          # Отправляем сообщение в таску, что нет открытых релизов с App=apps
          puts "Отправляем сообщение в таску, что нет открытых релизов с App: #{apps}"
          # issue.post_comment <<-BODY
          #   {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
          #     Не найдены открытые релизы с App: #{apps}
          #     Начинаем проверку задач для создания смежных релизов
          #   {panel}
          # BODY
          # Начинаем процесс сбора данных по задачам
          # Запускаем сбор Apps в задачах, которые есть в релизе
          issue_links = issue.fields['issuelinks']

          deployes_issues = []
          issue_links.each do |linked_issue|
            deployes_issues.append(linked_issue['outwardIssue']['key']) if linked_issue['type']['outward'] == 'deployes'
          end

          puts deployes_issues

          issue_deployes_issues  = client.Issue.find(deployes_issues[0])
          puts issue_deployes_issues.to_json

          issues_apps_type = []
          deployes_issues.each do |issue_apps_type|
            issue_deployes_issues = client.Issue.find(issue_apps_type)
            # тут может быть несколько полей
            issues_apps_type.append(issue_deployes_issues.fields['customfield_12207'][0]['value'])
            puts issue_deployes_issues
            puts issue_deployes_issues.fields['customfield_12207'].length
          end
          puts issues_apps_type
        else
          # есть открытые релизы с таким типом апп, Отправляем сообщение, что нужно сначала закрыть их
          puts 'есть открытые релизы с таким типом апп, Отправляем сообщение, что нужно сначала закрыть их'
          issue.post_comment <<-BODY
            {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
              Найдены открытые релизы с App=#{apps}
              Необходимо завершить работу над ними, пережде чем продолжать работу в этом релизе
              Скрипт был остановлен (!)
            {panel}
          BODY
        end
      else
        # Завершаем скрипт и выводим сообщение в логе, что выбран то тот проект, для этого скрипта
        puts "Необходимо использовать данный скрипт для проверки только проектов Android/IOS! Текущий тип проекта #{issue.key[0..2].truncate("-",separator: '')}"
        issue.post_comment <<-BODY
            {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#ff6e6e}
              Необходимо использовать данный скрипт для проверки только проектов Android/IOS! Текущий тип проекта #{issue.key[0..2]}
            {panel}
        BODY
        exit 0
      end
    end
  end
end
