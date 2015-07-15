require 'jira'
require 'slop'
require 'pp'
require 'git'
require './lib/issue'

opts = Slop.parse do |o|
  # Connection settings
  o.string '-u', '--username', 'username', default: 'default'
  o.string '-p', '--password', 'password', default: 'bWx3h6wjHgHEyi'
  o.string '--site', 'site', default: 'default'
  o.string '--context_path', 'context path', default: ''
  o.string '--release', 'release', default: 'OTT-4749'

  o.string '-gu', '--gitusername', 'username', default: 'jenkins_ott'
  o.string '-gp', '--gitpassword', 'password', default: '9E=mCqM*'

  o.bool '--force', 'post comments to Jira', default: false

  o.on '--help', 'print the help' do
    puts o
    exit
  end
end

def git_repo(url, name, opts)
  if File.writable?(name)
    git_repo = Git.open(name)
  else
    uri = Addressable::URI.parse("#{url}.git")
    uri.user = opts[:gitusername]
    uri.password = opts[:gitpassword]
    git_repo = Git.clone(uri, name)
  end
  git_repo.reset_hard
  git_repo
end

def clean_branch(repo, branch)
  repo.branch(branch).delete
  repo.chdir do
    `git push origin :#{branch}`
  end
end

options = { auth_type: :basic }.merge(opts.to_hash)
client = JIRA::Client.new(options)

release = client.Issue.find(opts[:release])
release.related['branches'].each do |branch|
  if branch['name'].match "^#{release.key}-release"
    puts branch['repository']['name']
    puts branch['repository']['url']
    repo_path = git_repo(branch['repository']['url'],
                         branch['repository']['name'], opts)
    today = Time.new.strftime('%d.%m.%Y')
    old_branch = branch['name']
    repo_path.fetch
    repo_path.checkout(old_branch)
    new_branch = "#{release.key}-release-#{today}"
    repo_path.branch(new_branch).checkout
    repo_path.merge("origin/#{old_branch}")
    puts repo_path.diff(old_branch, new_branch).size
    if opts[:force]
      puts "Pushing #{new_branch} and deleting #{old_branch} branch"
      repo_path.push
      clean_branch(repo_path, old_branch)
    end
  end
end
