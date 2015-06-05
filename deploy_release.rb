require 'jira'
require 'slop'
require 'pp'
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

options = { auth_type: :basic }.merge(opts.to_hash)
client = JIRA::Client.new(options)

issue = client.Issue.find(opts[:release])
issue.opts_setter opts
issue.related['branches'].each do |branch|
  puts branch['name']
  puts branch['repository']['name']
  ENV["#{branch['repository']['name'].upcase}_DEPLOY"] = 'true'
  ENV["#{branch['repository']['name'].upcase}_BRANCH"] = branch['name']
end
