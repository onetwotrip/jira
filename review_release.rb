require 'simple_config'
require 'json'
require 'git'
require 'jira'
require_relative 'lib/check'
require_relative 'lib/repo'
require_relative 'lib/issue'

WORKDIR = SimpleConfig.git.workdir

JIRA_USERNAME = SimpleConfig.jira.user
JIRA_PASSWORD = SimpleConfig.jira.pass
JIRA_SITE = SimpleConfig.jira.site

post_to_ticket = ENV.fetch('ROOT_BUILD_CAUSE_REMOTECAUSE', nil) == 'true' ? true : false

fail_on_jscs = ENV.fetch('FAIL_ON_JSCS', false)
FAIL_ON_JSCS = fail_on_jscs ? !fail_on_jscs.empty? : false

TRANSITION = 'WTF'.freeze

Dir.mkdir WORKDIR unless Dir.exist? WORKDIR

# Workflow
# Collect data about release and Issue
unless (triggered_issue = SimpleConfig.jira.issue)
  print "No issue - no cry!\n"
  exit 2
end

jira = JIRA::Client.new username: JIRA_USERNAME,
                        password: JIRA_PASSWORD,
                        site: JIRA_SITE,
                        auth_type: :basic,
                        context_path: ''
# noinspection RubyArgCount
issue = jira.Issue.jql("key = #{triggered_issue}")
if (issue.is_a? Array) && (issue.length > 1)
  fail "WTF??? Issue search returned #{issue.length} elements!"
elsif issue.is_a? Array
  issue = issue[0]
end

errors = []

fail_release = false

branches = issue.related['branches']

exit 0 if branches.empty?

branches.each do |branch|
  branch_name = branch['name']
  repo_name = branch['repository']['name']
  repo_url = branch['repository']['url']
  # Checkout repo
  print "Working with #{repo_name}\n"
  g_rep = GitRepo.new repo_url, repo_name, workdir: WORKDIR

  g_rep.checkout 'master'
  g_rep.git.pull
  g_rep.git.branch(branch_name).delete rescue Git::GitExecuteError # rubocop:disable Style/RescueModifier
  begin
    g_rep.git.checkout branch_name
  rescue Git::GitExecuteError => e
    puts "Branch #{branch_name} does not exist any more...\n#{e.message}"
    next
  end

  # g_rep.checkout branch_name
  puts 'Merging new version'
  g_rep.merge! "origin/#{branch_name}"

  # Try to merge master to branch
  unless ENV['NO_MERGE']
    begin
      g_rep.merge! 'master'
    rescue Git::GitExecuteError => e
      errors << "Failed to merge master to branch #{branch_name}.
Git had this to say: {noformat}#{e.message}{noformat}"
      fail_release = true
      g_rep.abort_merge!
    end
    g_rep.checkout branch_name
  end

  puts 'JSCS/JSHint'

  # JSCS; JSHint
  unless ENV['NO_JSCS']
    res_text = g_rep.check_diff 'HEAD'
    unless res_text.empty?
      errors << "Checking branch #{branch_name}:\n{noformat}#{res_text}{noformat}"
      fail_release = true if FAIL_ON_JSCS
    end
  end

  puts 'NPM Test'
  # NPM test
  test_out = ''
  test_out = g_rep.run_tests! unless ENV['NO_TESTS']
  unless test_out.empty?
    fail_release = true
    errors << "{noformat}#{test_out}{noformat}"
  end
end

comment_text = "Automatic code review complete.\n"

# If something failed:
if fail_release
  comment_text = "\nThere were some errors:\n#{errors.join("\n")}"

  # return issue to "In Progress"
  if issue.has_transition? TRANSITION
    puts 'TRANSITIONING DISABLED'
    issue.transition TRANSITION
  else
    print "No transition #{TRANSITION} available."
    comment_text = "Unable to transition issue to \"In Progress\" state.\n\n" + comment_text
  end

else
  comment_text << "\nMerge master: #{ENV['NO_MERGE'] ? 'SKIPPED' : 'PASSED'}
JSCS/JSHint: #{ENV['NO_JSCS'] ? 'SKIPPED' : 'PASSED'}
npm test: #{ENV['NO_TEST'] ? 'SKIPPED' : 'PASSED'}\n"
  unless errors.empty?
    comment_text << "There were some errors:\n#{errors.join "\n"}"
  end
end

comment_text << "\nBuild URL: #{ENV.fetch('BUILD_URL', 'none')}"
puts comment_text
issue.post_comment comment_text if post_to_ticket
