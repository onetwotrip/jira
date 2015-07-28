require 'json'
require 'git'
require 'jira'
require_relative 'lib/check'
require_relative 'lib/repo'
require_relative 'lib/issue'

WORKDIR = ENV.fetch('WORKDIR', '../repos/')
BASEURL = ENV.fetch('BB_URL', 'git@bitbucket.org:')

JIRA_USERNAME = ENV.fetch('JIRA_USERNAME', 'default')
JIRA_PASSWORD = ENV.fetch('JIRA_PASSWORD', 'bWx3h6wjHgHEyi')
JIRA_SITE = ENV.fetch('JIRA_SITE', 'default')


Dir.mkdir WORKDIR unless Dir.exist? WORKDIR

# Workflow
# Collect data about release and Issue
unless (triggered_issue = ENV['ISSUE'])
  print "No issue - no cry!\n"
  exit 2
end

jira = JIRA::Client.new username: JIRA_USERNAME, password: JIRA_PASSWORD, site: JIRA_SITE, auth_type: :basic,
                        context_path: ''
issue = jira.Issue.jql("key = #{triggered_issue}")
if issue.is_a? Array and issue.length > 1
  fail "WTF??? Issue search returned #{issue.length} elements!"
elsif issue.is_a? Array
  issue = issue[0]
end

errors = []

branches = issue.related['branches']
branches.each do |branch|
  branch_name = branch['name']
  repo_name = branch['repository']['name']
  repo_url = branch['repository']['url']
  # Checkout repo
  print "Working with #{repo_name}\n"
  g_rep = nil
  Dir.chdir WORKDIR do
    print 'Cloning... '
    g_rep = git_repo repo_url, repo_name
    print "done.\n"
  end


  # Checkout branch
  g_rep.checkout branch_name
  # Try to merge master to branch
  begin
    g_rep.merge 'master'
  rescue Git::GitExecuteError => e
    errors << "Failed to merge master to branch #{branch_name}.\nGit had this to say: #{e.message}"
  end

  # JSCS; JSHint
  res_text = check_diff g_rep, branch_name
  unless res_text.empty?
    errors << "Checking branch #{branch_name}: #{res_text}"
  end

  # NPM test
  Dir.chdir "#{WORKDIR}/#{repo_name}" do
    out = ''
    exit_code = 0
    t = Thread.new do
      puts 'NPM install'
      out = `npm install 2>&1`
      puts 'NPM test'
      out += `npm test 2>&1`
      exit_code = $?
    end
    t.join
    if exit_code.to_i > 0
      errors << "Testing branch #{branch_name} failed:\n\n#{out}"
    end
  end
end

# If something failed:
unless errors.empty?
  # Comment with errors
  comment = issue.comments.build
  puts errors.join("\n")
  #comment.save({body:w errors.join("\n")})
  # return issue to "In Progress"
  #issue.transition 'In Progress'
end