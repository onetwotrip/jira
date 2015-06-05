require 'jira'
require 'slop'
require './lib/issue'

opts = Slop.parse do |o|
  # Connection settings
  o.string '-u', '--username', 'username', default: 'default'
  o.string '-p', '--password', 'password', default: 'bWx3h6wjHgHEyi'
  o.string '--site', 'site', default: 'default'
  o.string '--context_path', 'context path', default: ''
  o.string '--release', 'release', default: 'OTT-4487'

  o.bool '--dryrun', 'dont post comments to Jira', default: false

  o.on '--help', 'print the help' do
    puts o
    exit
  end
end

STDOUT.sync = true

options = { auth_type: :basic }.merge(opts.to_hash)
client = JIRA::Client.new(options)
issue = client.Issue.find(opts[:release])
issue.deploys.each do |deployed_issue|
  puts deployed_issue.key
  # Transition to DONE
  deployed_issue.transition 'To master'
end
