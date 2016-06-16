module Scenarios
  ##
  # DeployRelease scenario
  class DeployRelease
    attr_reader :opts

    def initialize(opts)
      @opts = opts
    end

    def run
      raise 'No stage!' unless ENV['STAGE']
      options = { auth_type: :basic }.merge(opts.to_hash)
      client = JIRA::Client.new(options)
      release = client.Issue.find(opts[:release])
      prs = release.related['pullRequests']
      git_style_release = opts[:release].tr('-', ' ').downcase.capitalize

      prs.select! { |pr| /^((#{opts[:release]})|(#{git_style_release}))/.match pr['name'] && pr['status'] != 'DECLINED' }

      if prs.empty?
        puts 'No pull requests for this task!'
        exit 1
      end

      puts prs.map { |pr| pr['name'] }
      pp prs

      prop_values = { 'STAGE' => ENV['STAGE'] }

      prs.each do |pr|
        repo_name = pr['url'].split('/')[-3]
        if pr['destination']['branch'] != 'master'
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
