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
      additional_values = {}
      front_projects = []

      if SimpleConfig.jira.issue
        jira = JIRA::Client.new SimpleConfig.jira.to_h
        begin
          issue = jira.Issue.find SimpleConfig.jira.issue
        rescue JIRA::HTTPError => e
          LOGGER.error("Got error: #{e.response.body}")
          exit 1
        end

        prs = issue.related['pullRequests']

        if prs.empty?
          LOGGER.error "Error: no valid pull requests found for the issue #{SimpleConfig.jira.issue}. Valid PR should contains '#{SimpleConfig.jira.issue}' in title"
          exit 1
        end

        LOGGER.info 'Checking for wrong PRs names:'

        prs.each do |pr|
          prname = pr['name'].dup
          puts "[#{prname}] - WRONG! Stripped. Bad guy: #{pr['author']['name']}" unless pr['name'].strip!.nil?

          #fix: jira bug??
          pr['cleaned_up_url'] =  pr['url'].split('/').uniq.join('/')
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
          elsif !projects_conf[Git::Utils.url_to_ssh(pr['cleaned_up_url']).to_s.split('/')[0..1].join('/') + '.git']
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
          title: 'Pullrequests status',
          headings: %w[status author url],
          rows: prs.map { |v| [v['reject'] || v['status'].green, v['author']['name'], v['cleaned_up_url']] }
        )

        prs.reject { |pr| pr['reject'] }.each do |pr|
          repo_name = Git::Utils.url_to_ssh(pr['cleaned_up_url']).to_s.split('/')[0..1].join('/') + '.git'
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
          skip = false

          unless ENV['SKIP_LIKEPROD'] == ''
            begin
              skipies = ENV['SKIP_LIKEPROD'].split(',')
              skip = true if skipies.include?(proj.downcase)
            rescue StandardError => e
              LOGGER.info "problems with SKIP_LIKEPROD: #{e.message}"
            end
          end

          if true?(ENV['WITHOUT_WEBFRONT'])
            front_projects = projects_conf.reduce([]) do |m, (_, v)|
              m.concat(v['projects']) if v['config']['name'].include?("webfront")
              m
              end.flatten
            skip_web = front_projects.to_s
            skip = true if skip_web.match(/"#{proj}"/)
          end

          skip = true if prop_values['PROJECTS'][proj]

          next if skip

          prop_values['PROJECTS'][proj] = {}
          prop_values['PROJECTS'][proj]['ENABLE'] = true
          prop_values['PROJECTS'][proj]['BRANCH'] = 'master'
        end
      end

      additional_values['KEEP_RELEASES'] = 1 if true? ENV['DYNAMIC_NODES_SYNC']

      puts Terminal::Table.new(
        title: 'Deploy projects',
        headings: %w[Project branch],
        rows: prop_values['PROJECTS'].map { |k, v| [k, v['BRANCH']] }
      )
      properties = { 'DEPLOY' => prop_values.to_json }
      properties = properties.merge(additional_values) unless additional_values.empty?
      JavaProperties.write(properties, './env.properties')

      exit 0
    end
  end
end
