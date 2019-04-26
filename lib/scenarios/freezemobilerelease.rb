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
      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Запущено формирование релизных веток(!)
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
          old_branch = branch['name']
          new_branch_dev = "feature/#{SimpleConfig.jira.issue}/#{issue.fields['fixVersions'].first['name']}"
          new_branch_master = "release/#{SimpleConfig.jira.issue}/#{issue.fields['fixVersions'].first['name']}"
          repo_path = git_repo(branch['repository']['url'])

          # copy -pre to -release
          LOGGER.info "Working with #{repo_path.remote.url.repo}"
          unless repo_path.is_branch? old_branch
            LOGGER.error "Branch #{old_branch} doesn't exists"
            exit(1)
          end

          LOGGER.info "Copying #{old_branch} to #{new_branch_dev} branch"
          cur_branch = repo_path.current_branch
          with repo_path do
            checkout(old_branch)
            pull
            branch(new_branch_dev).delete if is_branch?(new_branch_dev)
            branch(new_branch_dev).create
            checkout cur_branch
          end

          LOGGER.info "Copying #{old_branch} to #{new_branch_master} branch"
          cur_branch = repo_path.current_branch
          with repo_path do
            checkout(old_branch)
            pull
            branch(new_branch_master).delete if is_branch?(new_branch_master)
            branch(new_branch_master).create
            checkout cur_branch
          end

          LOGGER.info "Pushing #{new_branch_dev} and #{new_branch_master}. Deleting #{old_branch} branch"
          with repo_path do
            push(repo_path.remote('origin'), new_branch_master) # push -release to origin
            push(repo_path.remote('origin'), new_branch_dev) # push -feature to origin
            branch(old_branch).delete_both if old_branch != 'master' # delete -pre from local/remote
            LOGGER.info "Creating PR from #{new_branch_master} to 'master'"
            create_pullrequest(
              SimpleConfig.bitbucket[:username],
              SimpleConfig.bitbucket[:password],
              new_branch_master,
              'master'
            )
            LOGGER.info "Creating PR from #{new_branch_dev} to 'master'"
            create_pullrequest(
              SimpleConfig.bitbucket[:username],
              SimpleConfig.bitbucket[:password],
              new_branch_dev,
              'master'
            )
          end
        end

        LOGGER.info 'Get all labels again'
        issue          = jira.Issue.find(SimpleConfig.jira.issue)
        release_labels = []
        issue.api_pullrequests.each do |br|
          LOGGER.info("Repo: #{br.repo_slug}")
          release_labels << br.repo_slug
        end
        if release_labels.empty?
          LOGGER.error 'Made empty labels array! I will skip set up new labels step'
        else
          LOGGER.info "Add labels: #{release_labels.uniq} to release #{issue.key}"
          issue.save(fields: { labels: release_labels.uniq })
          issue.fetch
        end
      rescue StandardError => e
        issue.post_comment <<-BODY
        {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
         Не удалось собрать релизные ветки (x)
         Подробности в логе таски https://jenkins.twiket.com/view/RELEASE/job/freeze_release/
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
