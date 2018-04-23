module Scenarios
  ##
  # DeployRelease scenario
  class DeployRelease
    def run
      projects_conf = YAML.load_file(ENV['PROJECTS_CONF'])
      all_projects = projects_conf.map { |_, v| v['projects'] }.flatten.sort.uniq
      prop_values = {
        'CHECKMASTER' => ENV['CHECKMASTER'],
        'DEPLOY_USER' => ENV['DEPLOY_USER'],
        'PROJECTS' => {},
        'ROLES' => JSON.parse(ENV['USER_ROLES']),
        'STAGE' => ENV['STAGE'],
      }

      if SimpleConfig.jira.issue
        jira = JIRA::Client.new SimpleConfig.jira.to_h
        issue = jira.Issue.find SimpleConfig.jira.issue
        prs = issue.related['pullRequests']

        if prs.empty?
          LOGGER.error "Error: no pull requests found for the issue #{SimpleConfig.jira.issue}"
          exit 1
        end

        puts 'Checking for wrong PRs names:'

        prs.each do |pr|
          prname = pr['name'].dup
          puts "[#{prname}] - WRONG! Stripped. Bad guy: #{pr['author']['name']}" unless pr['name'].strip!.nil?
        end

        git_style_release = SimpleConfig.jira.issue.tr('-', ' ').downcase.capitalize
        prs.each do |pr|
          if pr['name'] !~ /^((#{SimpleConfig.jira.issue})|(#{git_style_release}))/
            LOGGER.warn "[#{pr['name']}] - WRONG NAME! \
                         Expedted /^((#{SimpleConfig.jira.issue})|(#{git_style_release}))/. \
                         Bad guy: #{pr['author']['name']}"
            pr['reject'] = 'WRONGNAME'.yellow
          elsif pr['status'] == 'DECLINED'
            LOGGER.warn "[#{pr['name']}] - DECLINED! Bad guy: #{pr['author']['name']}"
            pr['reject'] = 'DECLINED'.yellow
          elsif !projects_conf[Git::Utils.url_to_ssh(pr['url']).to_s.split('/')[0..1].join('/') + '.git']
            LOGGER.warn "[#{pr['name']}] - No project settings"
            pr['reject'] = 'NOCONFIG'.yellow
          elsif !pr['destination']['branch'].include? 'master'
            LOGGER.warn "[#{pr['name']}] - WTF? Why is this Pull Request here? o_O (destination: #{pr['destination']['branch']}"
            pr['reject'] = 'NOTMASTER'.yellow
          elsif pr['status'] != 'OPEN'
            LOGGER.warn "[#{pr['name']}] - NOT OPEN! Bad guy: #{pr['author']['name']}"
            pr['reject'] = 'NOTOPEN'.yellow
          else
            LOGGER.info "[#{pr['name']}] - #{pr['status']} - OK"
          end
        end

        puts Terminal::Table.new(
          title:    'Pullrequests status',
          headings: %w[status author url],
          rows:     prs.map { |v| [v['reject'] || v['status'].green, v['author']['name'], v['url']] }
        )

        prs.reject { |pr| pr['reject'] }.each do |pr|
          repo_name = Git::Utils.url_to_ssh(pr['url']).to_s.split('/')[0..1].join('/') + '.git'
          projects_conf[repo_name]['projects'].each do |proj|
            prop_values['PROJECTS'][proj] = {}
            prop_values['PROJECTS'][proj]['ENABLE'] = true
            # If ROLLBACK true deploy without version (LIKEPROD)
            prop_values['PROJECTS'][proj]['BRANCH'] = pr['source']['branch'] unless true?(ENV['ROLLBACK'])
          end
        end
      end

      if true?(ENV['LIKEPROD'])
        all_projects.each do |proj|
          next if prop_values['PROJECTS'][proj]
          prop_values['PROJECTS'][proj] = {}
          prop_values['PROJECTS'][proj]['ENABLE'] = true
          prop_values['PROJECTS'][proj]['BRANCH'] = 'master'
        end
      end

      puts Terminal::Table.new(
        title:    'Deploy projects',
        headings: %w[Project branch],
        rows:      prop_values['PROJECTS'].map { |k, v| [k, v['BRANCH']] }
      )
      JavaProperties.write({ 'DEPLOY' => prop_values.to_json }, './env.properties')

      exit 0
    end
  end
end
