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

      release_issues = []
      # prepare release candidate branches
      issue.related['branches'].each do |branch|
        repo_path = git_repo(branch['repository']['url'])
        repo_path.chdir do
          `git fetch --prune`
        end
        unless branch['name'].match "^#{SimpleConfig.jira.issue}-pre"
          unless repo_path.is_branch? branch['name']
            LOGGER.error "[SKIP] #{branch['repository']['name']}/#{branch['name']} - branch doesn't exist"
            next
          end
          LOGGER.error "[SKIP] #{branch['repository']['name']}/#{branch['name']} - incorrect branch name"
          next
        end
        release_issues << branch
      end

      if release_issues.empty?
        LOGGER.error 'There is no -pre branches in release ticket'
        exit(1)
      end

      release_issues.each do |branch|
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
          create_pullrequest SimpleConfig.bitbucket.to_h.merge(src: new_branch)
        end
      end

      LOGGER.info 'Get all labels again'
      release_labels = issue.all_labels
      LOGGER.info "Add labels: #{release_labels} to release #{issue.key}"
      issue.save(fields: { labels: release_labels })
      issue.fetch
    end
  end
end
