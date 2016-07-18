module Scenarios
  ##
  # ReviewRelease scenario
  class ReviewRelease
    def run
      @result = {}
      transition = 'WTF'.freeze
      post_to_ticket = ENV.fetch('ROOT_BUILD_CAUSE_REMOTECAUSE', nil) == 'true' ? true : false
      dryrun = {
        jscs: ENV.fetch('DRYRUN_FOR_JSCS', false),
        jshint: ENV.fetch('DRYRUN_FOR_JSHINT', false),
      }

      workdir = SimpleConfig.git.workdir
      Dir.mkdir workdir unless Dir.exist? workdir
      Dir.chdir workdir || './'

      unless SimpleConfig.jira.issue
        puts "ReviewRelease: No issue - no cry!\n"
        exit 2
      end

      jira = JIRA::Client.new SimpleConfig.jira.to_h
      release = jira.Issue.find(SimpleConfig.jira.issue)

      release.related['branches'].each do |branch|
        unless branch['name'].match "^#{release.key}-pre"
          puts "Incorrect branch name: #{branch['name']}".red
          next
        end
        url = "#{branch['repository']['url']}/branch/#{branch['name']}"
        repo = Git.get_branch url
        repo_name = repo.remote.url.repo
        branch_name = repo.current_branch
        dryrun[:npm] = SimpleConfig.test.npm.dryrun_for.include? repo_name

        puts "Working with #{repo_name} branch #{branch_name}".green
        @result[repo_name] = []
        [:jscs, :jshint, :npm].each do |name|
          puts "Checking #{repo_name}:#{branch_name} for #{name} test".green
          test = Ott::Test.new repo: repo,
                               name: name,
                               dryrun: dryrun[name]
          test.run!
          @result[repo_name].push test
        end
      end

      # Print details of fails
      @result.each do |branch, tests|
        tests.each do |test|
          unless test.status
            puts "Details of fails for #{branch} #{test.name}:".red
            puts test.outs
          end
        end
      end

      comment_text = ERB.new(File.read("#{Ott::Helpers.root}/views/release_test_result.erb"), nil, '<>').result(binding)
      # Print summary
      puts comment_text
      # If something failed post comment to release
      if @result.values.flatten.map(&:status).include? false
        if release.has_transition? transition
          puts "Set release #{release.key} to #{transition}"
          release.transition transition
        else
          puts "No transition #{transition} available.".red
          comment_text << "Unable to transition issue to #{transition} state."
        end
        release.post_comment comment_text.uncolorize if post_to_ticket
        exit 1
      end
    end
  end
end
