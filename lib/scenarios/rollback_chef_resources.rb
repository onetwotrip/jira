module Scenarios
  ##
  # RollbackChefResources scenario
  class RollbackChefResources
    def run
      repo_name = 'devops-chef-resources'

      jira_client = JIRA::Client.new SimpleConfig.jira.to_h
      issue_key = SimpleConfig.issue
      release_issue = jira_client.Issue.find(issue_key)

      LOGGER.info 'Fetching related branches'
      repo_branch_info = release_issue.related['branches'].find { |b| b['repository']['name'] == repo_name }
      LOGGER.info 'Fetching related branches - done'

      unless repo_branch_info
        LOGGER.warn "No resources to rollback for #{issue_key}"
        exit 0
      end

      repo_url = repo_branch_info['repository']['url']
      LOGGER.info "Fetching repo #{repo_url}"
      git_repo = GitRepo.new(repo_url)
      LOGGER.info "Fetching repo #{repo_url} - done"

      branch_name = repo_branch_info['name']
      LOGGER.info "Checking out: #{branch_name}"
      git_repo.checkout("origin/#{branch_name}")
      git_repo.pull
      LOGGER.info "Checking out: #{branch_name} - done"

      LOGGER.info "Checking changed files for: #{branch_name}"
      diff_filelist = git_repo.changed_files('HEAD', 'origin/master')
      LOGGER.info diff_filelist
      LOGGER.info "Checking changed files for: #{branch_name} - done"

      roles_list = diff_filelist.select { |e| e.start_with?('roles/') }
      env_list = diff_filelist.select { |e| e.start_with?('environments/') }

      branch_name = 'master'
      LOGGER.info "Checking out: #{branch_name}"
      git_repo.checkout("origin/#{branch_name}")
      git_repo.pull
      LOGGER.info "Checking out: #{branch_name} - done"

      opts = {
        input: '',
        consul_template: '/usr/bin/consul-template',
        consul_template_args: '-vault-retry=false -vault-renew-token=false'
      }

      unless roles_list.empty?
        LOGGER.info 'Changed roles:'
        LOGGER.info roles_list

        LOGGER.info 'Syncing roles'
        roles_list.each do |role|
          if File.file?("#{git_repo.dir}/#{role}")
            LOGGER.info "Syncing #{role}"
            opts[:input] = "#{git_repo.dir}/#{role}"
            Scenarios::SyncChefResource.new(opts).run
            LOGGER.info "Syncing #{role} - done"
          else
            LOGGER.warn "Unknown role: '#{role}'"
          end
        end
        LOGGER.info 'Syncing roles - done'
      end

      unless env_list.empty?
        LOGGER.info 'Changed environments:'
        LOGGER.info env_list

        LOGGER.info 'Syncing environments'
        env_list.each do |env|
          if File.file?("#{git_repo.dir}/#{env}")
            LOGGER.info "Syncing #{env}"
            opts[:input] = "#{git_repo.dir}/#{env}"
            Scenarios::SyncChefResource.new(opts).run
            LOGGER.info "Syncing #{env} - done"
          else
            LOGGER.warn "Unknown environment: '#{env}'"
          end
        end
        LOGGER.info 'Syncing environments - done'
      end
    end
  end
end
