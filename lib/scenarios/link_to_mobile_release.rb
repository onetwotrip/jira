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

    def create_release_issue(project, issue, project_key = 'OTT', release_name = 'Release')
      project = project.find(project_key)
      puts "project #{project}"
      release = issue.build
      puts "release #{release}"
      puts "project.id #{project.id}"
      release.save(fields: { summary:   release_name, project: { id: project.id },
                             issuetype: { name: 'Release' } })
      release.fetch
      release
    rescue JIRA::HTTPError => jira_error
      error_message = jira_error.response['body_exists'] ? jira_error.message : jira_error.response.body
      LOGGER.error "Creation of release was failed with error #{error_message}"
      raise error_message
    end

    def run
      params = SimpleConfig.release

      unless params
        LOGGER.error 'No Release params in ENV'
        exit
      end

      # Получаем данные тикета
      client       = JIRA::Client.new SimpleConfig.jira.to_h
      issue        = client.Issue.find(SimpleConfig.jira.issue)
      issue_number = issue.key
      LOGGER.info Ott::Helpers.jira_link(issue_number).to_s

      # Уточняем какой тип проекта будет проверятся Андроид или IOS
      if issue_number[0..2].eql?('IOS') || issue_number[0..2].eql?('ADR')
        project = issue_number.include?('IOS') ? 'ios' : 'android'
        # Получаем значения поля apps из релиза
        # apps = issue.fields['customfield_12166']['value']
        apps = issue.fields['customfield_12208']['value']

        # Проверяем есть ли релизы AND/IOS с такими значениями и не закрытые
        # Производим поиск открытых релизов
        created_releases = client.Issue.jql(%(project = #{project} and issuetype = Release and status not in (Rejected, Done) and "App[Dropdown]" = #{apps} and issue != #{issue_number}), max_results: 100)

        # if created_releases == []
        # TODO: для проверки создания тикета
        if created_releases != []
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

          issues_apps_type = []
          deployes_issues.each do |issue_apps_type|
            issue_deployes_issues = client.Issue.find(issue_apps_type)
            # тут может быть несколько полей
            # проверяем длинну данного массива
            if (issue_deployes_issues.fields['customfield_12207'] != nil)
              if issue_deployes_issues.fields['customfield_12207'].length > 1
                issue_deployes_issues.fields['customfield_12207'].each_index do |index|
                  issues_apps_type.append(issue_deployes_issues.fields['customfield_12207'][index]['value'])
                end
              end
            else
              puts "У задачи #{issue_apps_type} неуказан Apps, необходимо его добавить и перезапустить скрипт"
              # issue.post_comment <<-BODY
              # {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
              #   У задачи #{issue_apps_type} неуказан Apps, необходимо его добавить и перезапустить скрипт
              # {panel}
              # BODY
            end
          end
          # Начинаем проверку существующих релизов для apps из задачи и создаем релизы
          puts "Начинаем проверку существующих релизов для apps из задачи и создаем релизы"
          puts issues_apps_type
          puts "##############"
          issues_apps_type_uniq = issues_apps_type.select { |i| issues_apps_type.count(i) <= 2 }.uniq

          puts "Список уникальных Apps"
          puts issues_apps_type_uniq

          puts issues_apps_type_uniq.class
          puts "##############"
          puts issues_apps_type_uniq[0]
          puts "##############"
          puts issues_apps_type_uniq.length
          issues_apps_type_uniq.each do |app_uniq|
            puts "app_uniq - #{app_uniq}"
          end

          issues_apps_type_uniq.each do |app_uniq|
            puts "Проверяем #{app_uniq}"
            created_releases = client.Issue.jql(
              %(project = #{project} and issuetype = Release and status not in (Rejected, Done) and "App[Dropdown]" = #{app_uniq} and issue != #{issue_number}), max_results: 100)
            puts "created_releases, #{created_releases}"
            puts created_releases.class

            if created_releases.length.zero?
              puts "Создаем релизы"
              # Создаем релизы
              begin
                release = client.Issue.build
                release.save(fields: { summary:   release_name, project: { id: project.id },
                                     issuetype: { name: 'Release' } })
                release.fetch
                puts release
              rescue RuntimeError => e
                puts e.message
                puts e.backtrace.inspect
                raise
              end

              LOGGER.info "Created new release #{release.key} from App label #{app_uniq}"
              LOGGER.info "Add labels: #{app_uniq} to release #{release.key}"
            else
              puts "По APPS=#{app_uniq} есть созданные релизы #{created_releases.to_json[0]}"
            end
          end
        else
          # есть открытые релизы с таким типом апп, Отправляем сообщение, что нужно сначала закрыть их
          puts "есть открытые релизы с таким типом апп #{apps}, Отправляем сообщение, что нужно сначала закрыть их"
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
        puts "Необходимо использовать данный скрипт для проверки только проектов Android/IOS! Текущий тип проекта #{issue_number[0..2].truncate("-", separator: '')}"
        issue.post_comment <<-BODY
            {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#ff6e6e}
              Необходимо использовать данный скрипт для проверки только проектов Android/IOS! Текущий тип проекта #{issue_number[0..2]}
            {panel}
        BODY
        exit 0
      end
    end
  end
end
