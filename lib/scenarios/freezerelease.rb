module Scenarios
  ##
  # FreezeRelease scenario
  class FreezeRelease
    def with(instance, &block)
      instance.instance_eval(&block)
      instance
    end

    def run
      LOGGER.info "Starting freeze_release for #{SimpleConfig.jira.issue}"
      jira = JIRA::Client.new SimpleConfig.jira.to_h
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
        release_issues = []
        related_branches = issue.related['branches']
        waiting = false
        timeout = 15
        counter = 1
        unless branches_contains_branch?(related_branches, '-pre')
          LOGGER.warn "Ticket doesn't contain any -pre branch. Try to wait..."
          waiting = true
        end

        while waiting
          sleep(20)
          counter += 1
          issue = jira.Issue.find(SimpleConfig.jira.issue)
          related_branches = issue.related['branches']
          if !branches_contains_branch?(related_branches, '-pre')
            LOGGER.warn "Still no - #{counter}/#{timeout}"
          else
            LOGGER.info 'Found -pre branch!'
            waiting = false
          end
          if counter >= timeout
            LOGGER.warn "Can't wait -pre branch! Is jira ticket ok?"
            exit 1
          end
        end

        # prepare release candidate branches
        related_branches.each do |branch|
          repo_path = git_repo(branch['repository']['url'])
          repo_path.chdir do
            `git fetch --prune`
          end
          unless branch['name'].match "^#{SimpleConfig.jira.issue}-pre"
            LOGGER.error "[SKIP] #{branch['repository']['name']}/#{branch['name']} - incorrect branch name"
            next
          end
          # Check for case when branch has correct name, but was deleted from issue
          unless repo_path.is_branch? branch['name']
            LOGGER.error "[SKIP] #{branch['repository']['name']}/#{branch['name']} - branch doesn't exist"
            next
          end
          release_issues << branch
        end

        if release_issues.empty?
          LOGGER.error "Can't create any release branch"
          exit(1)
        end

        release_issues.each do |branch| # rubocop:disable Metrics/BlockLength
          today = Time.new.strftime('%d.%m.%Y')
          old_branch = branch['name']
          new_branch = "#{SimpleConfig.jira.issue}-release-#{today}"
          repo_path = git_repo(branch['repository']['url'])

          # copy -pre to -release
          LOGGER.info "Working with #{repo_path.remote.url.repo}"
          unless repo_path.is_branch? old_branch
            LOGGER.error "Branch #{old_branch} doesn't exists"
            exit(1)
          end

          LOGGER.info "Copying #{old_branch} to #{new_branch} branch"
          cur_branch = repo_path.current_branch
          with repo_path do
            checkout(old_branch)
            pull
            branch(new_branch).delete if is_branch?(new_branch)
            branch(new_branch).create
            checkout cur_branch
          end

          LOGGER.info "Pushing #{new_branch} and deleting #{old_branch} branch"
          with repo_path do
            push(repo_path.remote('origin'), new_branch) # push -release to origin
            branch(old_branch).delete_both if old_branch != 'master' # delete -pre from local/remote
            LOGGER.info "Creating PR from #{new_branch} to #{cur_branch}"
            create_pullrequest(
              new_branch
            )
          end
        end

        LOGGER.info 'Get all labels again'
        issue = jira.Issue.find(SimpleConfig.jira.issue)
        release_labels = []
        issue.branches.each do |br|
          LOGGER.info("Repo: #{br.repo_slug}")
          release_labels << br.repo_slug
        end
        if release_labels.empty?
          LOGGER.warn 'Made empty labels array! I will skip set up new labels step'
        else
          LOGGER.info "Add labels: #{release_labels.uniq} to release #{issue.key}"
          issue.save(fields: { labels: release_labels })
          issue.fetch
        end
      rescue StandardError => e
        issue.post_comment <<-BODY
        {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
         Не удалось собрать релизные ветки (x)
         Подробности в логе таски #{ENV['BUILD_URL']}#{' '}
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

    def branches_contains_branch?(branches, branch)
      branches.each do |i|
        return true if i['name'].include?(branch)
      end
      false
    end
  end
end
