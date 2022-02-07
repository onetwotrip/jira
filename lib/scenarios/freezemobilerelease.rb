module Scenarios
  ##
  # FreezeRelease scenario
  class FreezeMobileRelease
    def with(instance, &block)
      instance.instance_eval(&block)
      instance
    end

    def run # rubocop:disable Metrics/MethodLength
      LOGGER.info "Starting freeze_release for #{SimpleConfig.jira.issue}"
      jira  = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Запущено формирование релизных веток(!)
        #{ENV['BUILD_URL']} 
        Ожидайте сообщение о завершении
      {panel}
      BODY

      begin
        fix_version = issue.fields['fixVersions'].first['name']
        if fix_version.empty?
          issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Не возможно начать формировать релизные ветки. У тикета нет fixVersion.
      {panel}
          BODY
        end

        release_label = issue.fields['labels'].first

        release_issues = []
        # prepare release candidate branches
        issue.related['branches'].each do |branch|
          repo_path = git_repo(branch['repository']['url'])
          repo_path.chdir do
            `git fetch --prune`
          end
          unless branch['name'].match "^#{SimpleConfig.jira.issue}-pre"
            LOGGER.error "[SKIP] #{branch['repository']['name']}/#{branch['name']} - incorrect branch name"
            next
          end
          # Check for case when issue has correct name, but was deleted from issue
          unless repo_path.is_branch? branch['name']
            LOGGER.error "[SKIP] #{branch['repository']['name']}/#{branch['name']} - branch doesn't exist"
            next
          end
          release_issues << branch
        end

        if release_issues.empty?
          LOGGER.error 'There is no -pre branches in release ticket'
          issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Не возможно начать формировать релизные ветки. У тикета нет веток -pre
      {panel}
          BODY
          exit(1)
        end

        release_issues.each do |branch| # rubocop:disable Metrics/BlockLength
          old_branch        = branch['name']
          new_branch_master = "release/#{SimpleConfig.jira.issue}/#{issue.fields['fixVersions'].first['name']}/#{release_label}"
          repo_path         = git_repo(branch['repository']['url'])

          # copy -pre to -release
          LOGGER.info "Working with #{repo_path.remote.url.repo}"
          unless repo_path.is_branch? old_branch
            LOGGER.error "Branch #{old_branch} doesn't exists"
            exit(1)
          end

          if issue.key.include?('IOS')
            LOGGER.warn 'This is IOS ticket, so i have to make also feature branch'
            new_branch_dev = "feature/#{SimpleConfig.jira.issue}/#{issue.fields['fixVersions'].first['name']}/#{release_label}"
            LOGGER.info "Copying #{old_branch} to #{new_branch_dev} branch"
            cur_branch = repo_path.current_branch
            with repo_path do
              checkout(old_branch)
              pull
              branch(new_branch_dev).delete if is_branch?(new_branch_dev)
              branch(new_branch_dev).create
              checkout cur_branch
              LOGGER.info "Pushing #{new_branch_dev}"
              push(repo_path.remote('origin'), new_branch_dev) # push -feature to origin
              LOGGER.info "Creating PR from #{new_branch_dev} to 'master'"
              create_pullrequest(new_branch_dev, 'master')
            end
          end

          LOGGER.info "Copying #{old_branch} to #{new_branch_master} branch"
          cur_branch = repo_path.current_branch
          with repo_path do
            checkout(old_branch)
            pull
            branch(new_branch_master).delete if is_branch?(new_branch_master)
            branch(new_branch_master).create
            checkout cur_branch
            LOGGER.info "Pushing #{new_branch_master}"
            push(repo_path.remote('origin'), new_branch_master) # push -release to origin
            LOGGER.info "Creating PR from #{new_branch_master} to 'master'"
            create_pullrequest(new_branch_master, 'master')
            LOGGER.info "Deleting #{old_branch} branch"
            branch(old_branch).delete_both if old_branch != 'master' # delete -pre from local/remote
          end
        end

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
      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Формирование релизных веток завершено (/)
      {panel}
      BODY
    end
  end
end
