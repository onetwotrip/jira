require 'jira'
require 'slop'
require './lib/issue'

opts = Slop.parse do |o|
  # Connection settings
  o.string '-u', '--username', 'username', default: 'default'
  o.string '-p', '--password', 'password', default: 'bWx3h6wjHgHEyi'
  o.string '--site', 'site', default: 'default'
  o.string '--contextpath', 'context path', default: ''
  o.string '--release', 'release', default: 'OTT-4487'

  o.on '--help', 'print the help' do
    puts o
    exit
  end
end

def jira_connect(opts)
  options = { username: opts[:username],
              password: opts[:password],
              site:     opts[:site],
              context_path: opts[:contextpath],
              auth_type: :basic
            }
  JIRA::Client.new(options)
end

client = jira_connect(opts)
issue = client.Issue.find(opts[:release])
issue.deploys.each do |deployed_issue|
  puts deployed_issue.key
  # Transition to DONE
  issue.transition 'To master'
end
