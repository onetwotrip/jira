require 'simple_config'
require 'colorize'
require 'jira'
require 'slop'
require 'pp'
require './lib/issue'
require_relative 'lib/repo'

opts = Slop.parse do |o|
  # Connection settings
  o.string '-u', '--username', 'username', default: SimpleConfig.jira.username
  o.string '-p', '--password', 'password', default: SimpleConfig.jira.password
  o.string '--site', 'site', default: SimpleConfig.jira.site
  o.string '--context_path', 'context path', default: ''
  o.string '--release', 'release', default: 'OTT-4749'

  o.string '-gu', '--gitusername', 'username', default: 'jenkins_ott'
  o.string '-gp', '--gitpassword', 'password', default: SimpleConfig.jira.password

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

puts "Starting freeze_release for #{opts[:release]}".green
options = { auth_type: :basic }.merge(opts.to_hash)
client = JIRA::Client.new(options)

release = client.Issue.find(opts[:release])
release.related['branches'].each do |branch|
  unless branch['name'].match "^#{release.key}-pre"
    puts "Incorrect branch #{branch['name']} name".red
    next
  end
  today = Time.new.strftime('%d.%m.%Y')
  old_branch = branch['name']
  new_branch = "#{release.key}-release-#{today}"

  repo_path = git_repo(branch['repository']['url'],
                       opts)

  # copy -pre to -release
  puts "Working with #{repo_path.remote.url.repo}".green
  repo_path.fetch
  unless repo_path.is_branch? old_branch
    puts "Branch #{old_branch} doesn't exists".red
    next
  end

  puts "Copying #{old_branch} to #{new_branch} branch".green
  cur_branch = repo_path.current_branch
  with repo_path do
    checkout(old_branch)
    pull
    branch(new_branch).delete if is_branch?(new_branch)
    branch(new_branch).create
    checkout cur_branch
  end

  next unless opts[:force]
  puts "Pushing #{new_branch} and deleting #{old_branch} branch".green
  with repo_path do
    push(repo_path.remote('origin'), new_branch) # push -release to origin
    branch(old_branch).delete_both if old_branch != 'master' # delete -pre from local/remote
    puts "Creating PR from #{new_branch} to #{cur_branch}".green
    create_pullrequest SimpleConfig.bitbucket.to_h.merge(src: new_branch)
  end
end
