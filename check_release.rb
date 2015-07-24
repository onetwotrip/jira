require 'json'
require 'git'
require 'sendgrid-ruby'
require_relative 'lib/check'
require_relative 'lib/repo'

WORKDIR = ENV.fetch('WORKDIR', '../repos/')
BASEURL = ENV.fetch('BB_URL', 'git@bitbucket.org:')
EMAIL_FROM = ENV.fetch('SG_FROM', 'default@default.com')
SG_USER = ENV.fetch('SG_USER', 'user')
SG_KEY = ENV.fetch('SG_KEY', 'pass')

if not ENV['payload'] or ENV['payload'].empty?
  print "No payload - no result\n"
  exit 2
end

payload = JSON.parse ENV['payload']

repo_name = payload['repository']['name']
print "Working with #{repo_name}\n"

new_commit = payload['push']['changes'][0]['new']['target']['hash']
old_commit = payload['push']['changes'][0]['old']['target']['hash']

# get latest
Dir.mkdir WORKDIR unless Dir.exist? WORKDIR

g_rep = nil
Dir.chdir WORKDIR do
  print 'Cloning... '
  g_rep = git_repo BASEURL + payload['repository']['full_name'], repo_name
  print "done.\n"
end

res_text = check_diff(g_rep, new_commit, old_commit)

exit 0 if res_text.empty?

author_name = g_rep.gcommit(new_commit).author.name
email_to = g_rep.gcommit(new_commit).author.email


print res_text
print "Will be emailed to #{email_to}\n"

mail = SendGrid::Mail.new do |m|
  m.to = 'vadzay@onetwotrip.com'
  m.from = EMAIL_FROM
  m.subject = "JSCS/JSHint: commit to #{payload['repository']['full_name']}"
  m.html = "Dear <a href=\"#{email_to}\">#{author_name}</a>!<br />
Your commit #{new_commit} to #{repo_name} has some issues with code check.<br /><pre>#{res_text}</pre>"
end

SendGrid::Client.new(api_user: SG_USER, api_key: SG_KEY).send mail
