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
      if !issue.key.include?('IOS') || !issue.key.include?('ADR')
        # Завершаем скрипт и выводим сообщение в логе, что выбран то тот проект, для этого скрипта
        puts "Необходимо использовать данный скрипт для проверки только проектов Android/IOS! Текущий тип проекта #{issue.key[0..2]}"
        exit 0
      else
        project = issue.key.include?('IOS') ? 'ios' : 'android'
        # Получаем значения поля apps из релиза
        apps = issue.fields['customfield_12166']['value']

        # Проверяем есть ли релизы AND/IOS с такими значениями и не закрытые
        # Производим поиск открытых релизов
        puts "project = #{project} and issuetype = Release and status not in (Rejected, Done) and \"App[Dropdown]\" = #{apps}"
        created_releases = client.Issue.jql(
          %(project = #{project} and issuetype = Release and status not in (Rejected, Done) and "App[Dropdown]" = #{apps}), max_results: 100)

        if created_releases == []
          # Отправляем сообщение в таску, что нет открытых релизов с App= apps
          puts "Отправляем сообщение в таску, что нет открытых релизов с App=#{apps}"
        else
          # есть открытые релизы с таким типом апп, Отправляем сообщение, что нужно сначала закрыть их
          puts 'есть открытые релизы с таким типом апп, Отправляем сообщение, что нужно сначала закрыть их'
        end
        puts created_releases.to_json
      end
    end
  end
end
