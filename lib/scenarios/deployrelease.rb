module Scenarios
  ##
  # DeployRelease scenario
  class DeployRelease
    def run
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find SimpleConfig.jira.issue
      projects_conf = YAML.load_file(ENV['PROJECTS_CONF'])
      all_projects = projects_conf.map { |_, v| v['projects'] }.flatten.sort.uniq
      prop_values = {
        'CHECKMASTER' => ENV['CHECKMASTER'],
        'DEPLOY_USER' => ENV['DEPLOY_USER'],
        'PROJECTS' => {},
        'ROLES' => JSON.parse(ENV['USER_ROLES']),
        'STAGE' => ENV['STAGE'],
      }

      # Get unique labels from release issue and all linked issues
      labels = issue.labels
      issue.linked_issues('deployes').each do |linked_issue|
        labels.concat(linked_issue.labels)
      end
      labels = labels.uniq

      prs = issue.related['pullRequests']

      puts 'Checking for wrong PRs names:'

      prs.each do |pr|
        prname = pr['name'].dup
        unless pr['name'].strip!.nil?
          puts "[#{prname}] - WRONG! Stripped. Bad guy: #{pr['author']['name']}"
        end
      end

      git_style_release = SimpleConfig.jira.issue.tr('-', ' ').downcase.capitalize
      prs.reject! do |pr|
        if pr['name'] !~ /^((#{SimpleConfig.jira.issue})|(#{git_style_release}))/
          LOGGER.warn "[#{pr['name']}] - WRONG NAME! \
                       Expedted /^((#{SimpleConfig.jira.issue})|(#{git_style_release}))/. \
                       Bad guy: #{pr['author']['name']}"
          true
        elsif pr['status'] == 'DECLINED'
          LOGGER.warn "[#{pr['name']}] - DECLINED! Bad guy: #{pr['author']['name']}"
          true
        else
          LOGGER.info "[#{pr['name']}] - OK"
          false
        end
      end

      if prs.empty?
        puts 'No pull requests for this task!'
        exit 1
      end

      puts 'Selected PRs:'
      puts prs.map { |pr| pr['name'] }
      pp prs

      prs.each do |pr|
        repo_name = Git::Utils.url_to_ssh(pr['url']).to_s.split('/')[0..1].join('/') + '.git'
        unless pr['destination']['branch'].include? 'master'
          puts "WTF? Why is this Pull Request here? o_O (destination: #{pr['destination']['branch']}"
          next
        end

        if projects_conf[repo_name].nil?
          puts "WTF? Dunno project for #{repo_name}"
          next
        end

        projects_conf[repo_name]['projects'].each do |proj|
          prop_values['PROJECTS'][proj] = {}
          prop_values['PROJECTS'][proj]['ENABLE'] = true
          # If ROLLBACK true deploy without version (LIKEPROD)
          prop_values['PROJECTS'][proj]['BRANCH'] = pr['source']['branch'] unless true?(ENV['ROLLBACK'])
        end

        labels.map(&:upcase).each do |proj|
          next unless all_projects.include? proj
          prop_values['PROJECTS'][proj] = {}
          prop_values['PROJECTS'][proj]['ENABLE'] = true
          # If ROLLBACK true deploy without version (LIKEPROD)
          prop_values['PROJECTS'][proj]['BRANCH'] = pr['source']['branch'] unless true?(ENV['ROLLBACK'])
        end
      end

      if true?(ENV['LIKEPROD'])
        all_projects.each do |proj|
          next if prop_values['PROJECTS'][proj]
          prop_values['PROJECTS'][proj] = {}
          prop_values['PROJECTS'][proj]['ENABLE'] = true
          prop_values['PROJECTS'][proj]['BRANCH'] = ''
        end
      end

      pp prop_values

      JavaProperties.write({ 'DEPLOY' => prop_values.to_json }, './env.properties')

      exit 0
    end
  end
end
