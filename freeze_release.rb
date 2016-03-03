require 'simple_config'
require 'jira'
require 'slop'
require 'pp'
require 'git'
require './lib/issue'
require_relative 'lib/repo'

opts = Slop.parse do |o|
  # Connection settings
  o.string '-u', '--username', 'username', default: SimpleConfig.jira.user
  o.string '-p', '--password', 'password', default: SimpleConfig.jira.pass
  o.string '--site', 'site', default: SimpleConfig.jira.site
  o.string '--context_path', 'context path', default: ''
  o.string '--release', 'release', default: 'OTT-4749'

  o.string '-gu', '--gitusername', 'username', default: 'jenkins_ott'
  o.string '-gp', '--gitpassword', 'password', default: SimpleConfig.jira.pass

  o.bool '--force', 'post comments to Jira', default: false

  o.on '--help', 'print the help' do
    puts o
    exit
  end
end

def with(instance, &block)
  instance.instance_eval(&block)
  instance
end

options = { auth_type: :basic }.merge(opts.to_hash)
client = JIRA::Client.new(options)

release = client.Issue.find(opts[:release])
release.related['branches'].each do |branch|
  next unless branch['name'].match "^#{release.key}-pre"
  puts branch['repository']['name']
  today = Time.new.strftime('%d.%m.%Y')
  old_branch = branch['name']
  new_branch = "#{release.key}-release-#{today}"

  repo_path = git_repo(branch['repository']['url'],
                       branch['repository']['name'],
                       opts)
  with repo_path do
    fetch
    checkout(old_branch)
    pull
    branch(new_branch).checkout
    checkout(old_branch)
    branch(new_branch).delete
    branch(new_branch).checkout
    puts diff(old_branch, new_branch).size
  end

  next unless opts[:force]
  puts "Pushing #{new_branch} and deleting #{old_branch} branch"
  repo_path.push(repo_path.remote('origin'), new_branch)
  clean_branch(repo_path, old_branch)
end
