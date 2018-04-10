module Scenarios
  ##
  # ReviewRelease scenario
  class ReviewCommit
    def run
      # post_to_ticket = ENV.fetch('ROOT_BUILD_CAUSE_REMOTECAUSE', nil) == 'true' ? true : false
      post_to_ticket = ENV.fetch('ROOT_BUILD_CAUSE_REMOTECAUSE', nil) == 'true'

      fail_on_jscs = ENV.fetch('FAIL_ON_JSCS', false)
      fail_on_jshint = ENV.fetch('FAIL_ON_JSHINT', false)

      transition = 'WTF'.freeze

      workdir = SimpleConfig.git.workdir
      Dir.mkdir workdir unless Dir.exist? workdir
      Dir.chdir workdir || './'

      # Workflow
      # Collect data about release and Issue
      unless SimpleConfig.jira.issue
        puts "ReviewRelease: No issue - no cry!\n"
        exit 2
      end

      jira = JIRA::Client.new SimpleConfig.jira.to_h
      # noinspection RubyArgCount
      issue = jira.Issue.find(SimpleConfig.jira.issue)

      pullrequests = issue.pullrequests(SimpleConfig.git.to_h)
                          .filter_by_status('OPEN')
                          .filter_by_source_url(SimpleConfig.jira.issue)

      unless pullrequests.valid?
        issue.post_comment p("ReviewRelease: #{pullrequests.valid_msg}")
        exit
      end

      pullrequests.each do |pr|
        # Checkout repo
        puts "Clone/Open with #{pr.dst} branch #{pr.dst.branch} and merge #{pr.src.branch}".green
        begin
          pr.repo
          puts 'Changed files:', pr.repo.diff('origin/HEAD').map(&:path)
        rescue Git::GitExecuteError => e
          puts e.message.red
          next
        end

        # JSCS
        unless ENV['NO_JSCS']
          puts 'Checking JSCS'.green
          pr.run_tests(name: :jscs, dryrun: !fail_on_jscs)
        end

        # JSHint
        unless ENV['NO_JSHINT']
          puts 'Checking JSHint'.green
          pr.run_tests(name: :jshint, dryrun: !fail_on_jshint)
        end

        # NPM test
        npm_dryrun = SimpleConfig.test.npm.dryrun_for.include? pr.dst.repo
        unless ENV['NO_TESTS']
          puts 'NPM Test'.green
          pr.run_tests(name: :npm, dryrun: npm_dryrun, scope: 'commit')
        end
      end
      comment_text = <<COMMENT_TEXT
      Automatic code review complete.
      Merge master: #{ENV['NO_MERGE'] ? 'SKIPPED' : 'PASSED'}
      JSCS:     #{if ENV['NO_JSCS']
                    'SKIPPED'
                  else
                    pullrequests.tests_status_string(:jscs)
                  end}
      JSHint:   #{if ENV['NO_JSHINT']
                    'SKIPPED'
                  else
                    pullrequests.tests_status_string(:jshint)
                  end}
      npm test: #{if ENV['NO_TEST']
                    'SKIPPED'
                  else
                    pullrequests.tests_status_string(:npm)
                  end}
COMMENT_TEXT
      # If something failed:
      unless pullrequests.tests_status
        comment_text << "There were some errors:\n\t#{pullrequests.tests_fails.join("\n\t")}\n"
        # return issue to "In Progress"
        if issue.has_transition? transition
          puts 'transitionING DISABLED'
          issue.transition transition
        else
          puts "No transition #{transition} available.".red
          comment_text << "Unable to transition issue to \"In Progress\" state.\n"
        end
      end

      puts "Errors: #{pullrequests.tests_fails.join(' ')}".red
      pullrequests.each do |pr|
        pr.tests.each do |test|
          unless test.code
            puts "Details for #{test.name}:".red
            puts test.outs
          end
        end
      end

      comment_text << "\nBuild URL: #{ENV.fetch('BUILD_URL', 'none')}"
      puts 'Summary comment text:'.green
      puts comment_text
      issue.post_comment comment_text if post_to_ticket
      exit 1 unless pullrequests.tests_status
    end
  end
end
