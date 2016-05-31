require 'simple_config'
require 'colorize'
require 'json'
require 'git'
require 'jira'
require_relative 'lib/check'
require_relative 'lib/repo'
require_relative 'lib/issue'

post_to_ticket = ENV.fetch('ROOT_BUILD_CAUSE_REMOTECAUSE', nil) == 'true' ? true : false

FAIL_ON_JSCS = ENV.fetch('FAIL_ON_JSCS', false)

TRANSITION = 'WTF'.freeze

WORKDIR = SimpleConfig.git.workdir
Dir.mkdir WORKDIR unless Dir.exist? WORKDIR
Dir.chdir WORKDIR || './'

# Workflow
# Collect data about release and Issue
unless (triggered_issue = SimpleConfig.jira.issue)
  print "No issue - no cry!\n"
  exit 2
end

jira = JIRA::Client.new SimpleConfig.jira.to_h
# noinspection RubyArgCount
issue = jira.Issue.jql("key = #{triggered_issue}")
raise "WTF??? Issue search returned #{issue.length} elements!" if (issue.is_a? Array) && (issue.length > 1)
issue = issue[0] if issue.is_a? Array

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
  rescue Git::GitExecuteError => e
    puts e.message.red
    next
  end
  NPM_DRYRUN = SimpleConfig.test.npm.dryrun_for.include? pr.dst.repo
  # JSCS; JSHint
  unless ENV['NO_JSCS']
    puts 'Checking JSCS/JSHint'.green
    pr.run_tests(:js, dryrun: !FAIL_ON_JSCS)
  end

  # NPM test
  unless ENV['NO_TESTS']
    puts 'NPM Test'.green
    pr.run_tests(:npm, dryrun: NPM_DRYRUN)
  end
end
comment_text = <<EOS
Automatic code review complete.
Merge master: #{ENV['NO_MERGE'] ? 'SKIPPED' : 'PASSED'}
JSCS/JSHint:  #{if ENV['NO_JSCS']
                  'SKIPPED'
                else
                  pullrequests.tests_status_string(:js)
                end}
npm test:     #{if ENV['NO_TEST']
                  'SKIPPED'
                else
                  pullrequests.tests_status_string(:npm)
                end}
EOS
# If something failed:
unless pullrequests.tests_status
  comment_text << "There were some errors:\n\t#{pullrequests.tests_fails.join("\n\t")}\n"
  # return issue to "In Progress"
  if issue.has_transition? TRANSITION
    puts 'TRANSITIONING DISABLED'
    issue.transition TRANSITION
  else
    puts "No transition #{TRANSITION} available.".red
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
