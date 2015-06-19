require 'jira'
require 'slop'
require 'pp'
require 'java-properties'
require './lib/issue'

opts = Slop.parse do |o|
  # Connection settings
  o.string '-u', '--username', 'username', default: 'default'
  o.string '-p', '--password', 'password', default: 'bWx3h6wjHgHEyi'
  o.string '--site', 'site', default: 'default'
  o.string '--context_path', 'context path', default: ''
  o.string '--release', 'release', default: 'OTT-4487'

  o.on '--help', 'print the help' do
    puts o
    exit
  end
end

env_export = {}

options = { auth_type: :basic }.merge(opts.to_hash)
client = JIRA::Client.new(options)

release = client.Issue.find(opts[:release])

release.related['branches'].each do |branch|
  puts branch['name']
  puts branch['repository']['name']
  env_export["#{branch['repository']['name'].upcase}_DEPLOY"] = 'true'
  env_export["#{branch['repository']['name'].upcase}_BRANCH"] = branch['name']
end

pp env_export

JavaProperties.write(env_export, './.properties')
