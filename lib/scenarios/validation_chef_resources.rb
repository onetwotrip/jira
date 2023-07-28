module Scenarios
  ##
  # ValidationChefResources scenario
  class ValidationChefResources
    def run
      repo_name = 'devops-chef-resources'

      jira_client = JIRA::Client.new SimpleConfig.jira.to_h
      issue_key = SimpleConfig.issue
      release_issue = jira_client.Issue.find(issue_key)

      LOGGER.info 'Fetching related branches'
      repo_branch_info = release_issue.related['branches'].find { |b| b['repository']['name'] == repo_name }
      LOGGER.info 'Fetching related branches - done'

      unless repo_branch_info
        LOGGER.warn "No resources to sync for #{issue_key}"
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

      opts = {
        input: '',
        consul_template: '/usr/bin/consul-template',
        consul_template_args: '-vault-retry=false -vault-renew-token=false -dry'
      }

      unless roles_list.empty?
        LOGGER.info 'Changed roles:'
        LOGGER.info roles_list

        LOGGER.info "Validation roles"
        roles_list.each do |role|
          if File.file?("#{git_repo.dir}/#{role}")
            LOGGER.info "Validation role: '#{role}'"
            opts[:input] = "#{git_repo.dir}/#{role}"
            Scenarios::ValidationChefResource.new(opts).run
            LOGGER.info "Validation role: '#{role}' - done"
          else
            LOGGER.warn "Removed role: '#{role}'"
          end
        end
      end

      unless env_list.empty?
        LOGGER.info 'Changed environments:'
        LOGGER.info env_list

        LOGGER.info "Validation environments"
        env_list.each do |env|
          if File.file?("#{git_repo.dir}/#{env}")
            LOGGER.info "Validation environment: '#{env}'"
            opts[:input] = "#{git_repo.dir}/#{env}"
            Scenarios::ValidationChefResource.new(opts).run
            LOGGER.info "Validation environment: '#{env}' - done"
          else
            LOGGER.warn "Removed environment: '#{env}'"
          end
        end
      end
    end
  end
end
