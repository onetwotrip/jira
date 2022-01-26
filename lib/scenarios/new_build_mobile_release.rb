module Scenarios
  # Build mobile release
  # From develop
  # Release branch for ADR prj
  # Release and feature branch for IOS prj
  class NewBuildMobileRelease # rubocop:disable Metrics/ClassLength
    def with(instance, &block)
      instance.instance_eval(&block)
      instance
    end

    def run
      LOGGER.info("Build mobile release from ticket #{SimpleConfig.jira.issue}")
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Запущено формирование релиза(!)
        Ожидайте сообщение о завершении
        Логи: #{ENV['BUILD_URL']}
      {panel}
      BODY

      prepare_release_branches(issue) if release_ticket_ok?(issue)

      set_fix_version_to_all_tasks(issue)

      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#10B924|bgColor=#F1F3F1}
        Формирование релиза завершено (/)
        Логи: #{ENV['BUILD_URL']}
      {panel}
      BODY
      LOGGER.info('Build mobile release - Success!')
    end

    def release_ticket_ok?(issue) # rubocop:disable Metrics/PerceivedComplexity
      # Check fix Version exist
      if issue.fields['fixVersions'].empty?
        issue.post_comment <<-BODY
            {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F04D2A|bgColor=#F1F3F1}
              У релизного тикета не выставлен 'Fix Version/s'(!)
              Сборка прекращена. Исправьте проблему и перезапустите сборку
            {panel}
        BODY
        LOGGER.error "У релизного тикета не выставлен 'Fix Version/s'"
        exit(1)
      end

      # Check release label exist and only one
      release_labels = issue.fields['labels']
      if release_labels.empty?
        issue.post_comment <<-BODY
            {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F04D2A|bgColor=#F1F3F1}
              Релизный тикет не содержит label, указывающий тип сборки релиза
              Сборка прекращена. Исправьте проблему и перезапустите сборку
            {panel}
        BODY
        LOGGER.error 'Релизный тикет не содержит label, указывающий тип сборки релиза'
        exit(1)
      elsif release_labels.size > 1
        issue.post_comment <<-BODY
          {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F04D2A|bgColor=#F1F3F1}
            Релизный тикет содержит больше чем 1 Label. Разрешено не более 1.
            Сборка прекращена. Исправьте проблему и перезапустите сборку
          {panel}
        BODY
        LOGGER.error "Релизный тикет содержит больше чем 1 Label: #{release_labels}"
        exit(1)
      end

      # Check link type
      if issue.linked_issues('deployes').empty?
        issue.post_comment <<-BODY
            {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F04D2A|bgColor=#F1F3F1}
              Релизный тикет не содержит тикетов, прилинкованных по типу deployes.
              Сборка прекращена. Исправьте проблему и перезапустите сборку
            {panel}
        BODY
        LOGGER.error 'Релизный тикет не содержит тикетов, прилинкованных по типу deployes'
        exit(1)
      end

      LOGGER.info "Number of issues: #{issue.linked_issues('deployes').size}"
      badissues = {}

      # Check linked issues for merged PR
      issue.linked_issues('deployes').each do |issue| # rubocop:disable Metrics/BlockLength
        LOGGER.info "Working on #{issue.key}"
        has_merges = false
        merge_fail = false
        valid_pr = []
        # Check ticket status
        LOGGER.info "Ticket #{issue.key} has status: #{issue.status.name}, but should 'Merge ready'" if issue.status.name != 'Merge ready'

        # Check PR exist in ticket
        if issue.related['pullRequests'].empty?
          if !issue.related['branches'].empty?
            body = "#{issue.key}: There is no pullrequest, but there is branhes. I'm afraid of changes are not at develop"
            badissues[:absent] = [] unless badissues.key?(:absent)
            badissues[:absent].push(issue.key)
            LOGGER.fatal body
            issue.post_comment body
            merge_fail = true
          else
            LOGGER.info "#{issue.key}: ticket without PR and branches"
            has_merges = true
          end
        else
          valid_pr << false
          issue.related['pullRequests'].each do |pullrequest|
            next if pullrequest['status'] == 'DECLINED'

            # Check PR match with ticket number
            if pullrequest['source']['branch'].include? issue.key
              valid_pr << true
              # Check PR status: open, merged
              if pullrequest['status'] != 'MERGED'
                LOGGER.fatal "#{issue.key}: PR with task number not merged in develop"
                issue.post_comment 'Not merged PR found. Please merge it into develop and update -pre branch before go next step'
                merge_fail = true
              else
                LOGGER.info "#{issue.key}: PR already merged in develop"
                has_merges = true
              end
            else
              LOGGER.warn "#{issue.key}: Found PR with doesn't contains task number"
              badissues[:badname] = [] unless badissues.key?(:badname)
              badissues[:badname].push(issue.key)
            end
          end
          # if ticket doesn't have valid pr (valid means contain issue number)
          unless valid_pr.include?(true)
            body = "#{issue.key}: There is no pullrequest contains issue number. I'm afraid of changes from ticket are not at develop"
            badissues[:absent] = [] unless badissues.key?(:absent)
            badissues[:absent].push(issue.key)
            LOGGER.fatal body
            issue.post_comment body
            merge_fail = true
          end
        end

        # Change issue status
        if !merge_fail && has_merges
          issue.transition 'Merge to release'
        elsif merge_fail
          issue.transition 'Merge Fail'
          LOGGER.fatal "#{issue.key} was not merged!"
        end
      end

      return true if badissues.empty?

      # If we have Merge Failed ticket we should post_comment about them
      LOGGER.fatal 'Not Merged:'
      badissues.each_pair do |status, keys|
        LOGGER.fatal "#{status}: #{keys.size}"
        keys.uniq.each { |i| LOGGER.fatal i }
      end
      issue.post_comment <<-BODY
            {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F04D2A|bgColor=#F1F3F1}
              Среди прилинкованных тикетов, есть тикеты с Merge Failed статусом.
              Нужно каждый проверить и решить, что с ним делать
              Логи: #{ENV['BUILD_URL']}
            {panel}
      BODY
    end

    def prepare_release_branches(issue)
      begin
        LOGGER.info 'Prepare release branches!'
        repo_url = repo_for(issue)
        repo_path = git_repo(repo_url)
        # repo_path.chdir do
        #   `git fetch origin --prune`
        # end
        release_label = issue.fields['labels'].first
        release_branch = "release/#{SimpleConfig.jira.issue}/#{issue.fields['fixVersions'].first['name']}/#{release_label}"
        create_branch_and_pr(repo_path, release_branch, repo_url)

        if issue.key.include?('IOS')
          LOGGER.warn 'This is IOS ticket, so i have to make also feature branch'
          release_branch = "feature/#{SimpleConfig.jira.issue}/#{issue.fields['fixVersions'].first['name']}/#{release_label}"
          create_branch_and_pr(repo_path, release_branch, repo_url)
        end
      rescue StandardError => e
        issue.post_comment <<-BODY
        {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
         Не удалось собрать релизные ветки (x)
         Подробности в логе таски #{ENV['BUILD_URL']} 
        {panel}
        BODY
        LOGGER.error "Не удалось собрать релизные ветки, ошибка: #{e.message}, трейс:\n\t#{e.backtrace.join("\n\t")}"
        exit(1)
      end
    end

    def create_branch_and_pr(repo_path, release_branch, repo_name)
      LOGGER.info "Create #{release_branch}"
      prepare_branch(repo_path, 'develop', release_branch, true)
      LOGGER.info "Push '#{release_branch}' to '#{repo_name}'"
      local_repo = repo_path
      LOGGER.info "Merge master into #{release_branch}"
      local_repo.merge('master', "merge master to #{release_branch}")
      LOGGER.info 'Push to remote'
      local_repo.push('origin', release_branch)
      LOGGER.info 'Push success!'
      with repo_path do
        LOGGER.info 'Create PR'
        new_create_pullrequest(release_branch, 'master')
        LOGGER.info 'Success!'
      end
    end

    def set_fix_version_to_all_tasks(issue)
      fix_version = issue.fields['fixVersions'].first['name']
      LOGGER.info "Start to set Fix Versions: #{fix_version} to tickets"
      issue.linked_issues('deployes').each do |subissue|
        result = subissue.save(fields: { fixVersions: [{ name: fix_version }] })
        if result
          subissue.fetch
          LOGGER.info "Set Fix Versions: #{fix_version} Ticket: #{subissue.key}"
        else
          LOGGER.error "Cant'set Fix Versions: #{fix_version} Ticket: #{subissue.key}"
          next
        end
      end
    end

    def repo_for(issue)
      case issue.key.to_s
        when /ADR-/
          issue_type_name = issue.attrs['fields'].fetch('issuetype').fetch('name')
          LOGGER.warn("Issuetype = #{issue_type_name}")
          case issue.attrs['fields'].fetch('issuetype').fetch('name')
            when /B2B_/
              'https://bitbucket.org/OneTwoTrip/android_b2b'
            else
              'https://bitbucket.org/OneTwoTrip/android_ott'
          end
        when /IOS-/
          'https://bitbucket.org/OneTwoTrip/ios-12trip'
        else
          LOGGER.error "Cant' get repo_url for #{issue.key}. Only for: ARD, IOS projects"
          exit 1
      end
    end
  end
end
