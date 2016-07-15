module Scenarios
  ##
  # DeployRelease scenario
  class DeployRelease
    def run
      raise 'No stage!' unless ENV['STAGE']
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find SimpleConfig.jira.issue

      prs = issue.related['pullRequests']
      git_style_release = SimpleConfig.jira.issue.tr('-', ' ').downcase.capitalize

      prs.select! { |pr| /^((#{SimpleConfig.jira.issue})|(#{git_style_release}))/.match pr['name'] && pr['status'] != 'DECLINED' }

      if prs.empty?
        puts 'No pull requests for this task!'
        exit 1
      end

      puts prs.map { |pr| pr['name'] }
      pp prs

      prop_values = { 'STAGE' => ENV['STAGE'] }

      prs.each do |pr|
        repo_name = pr['url'].split('/')[-3]
        unless pr['destination']['branch'].include? 'master'
          puts "WTF? Why is this Pull Request here? o_O (destination: #{pr['destination']['branch']}"
          next
        end
        prop_values["#{repo_name.upcase}_BRANCH"] = pr['source']['branch']
      end

      pp prop_values

      JavaProperties.write prop_values, './.properties'

      exit 0
    end
  end
end
