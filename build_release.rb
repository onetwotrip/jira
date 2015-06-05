require 'jira'
require 'pp'
require 'git'
require 'slop'
require 'json'
require 'rest-client'
require 'addressable/uri'
require './lib/issue'

opts = Slop.parse do |o|
  # Connection settings
  o.string '-u', '--username', 'username', default: 'default'
  o.string '-p', '--password', 'password', default: 'bWx3h6wjHgHEyi'
  o.string '--site', 'site', default: 'default'
  o.string '--context_path', 'context path', default: ''
  o.string '--release', 'release', default: 'OTT-4749'
  o.string '--source', 'source branch', default: 'master'
  o.string '--postfix', 'branch name postfix', default: 'pre'

  o.string '-gu', '--gitusername', 'username', default: 'jenkins_ott'
  o.string '-gp', '--gitpassword', 'password', default: '9E=mCqM*'

  o.bool '--push', 'push to remote', default: false
  o.bool '--clean', 'clean local and remote branches', default: false
  o.bool '--dryrun', 'do not post comments to Jira', default: false
  o.bool '--ignorelinks', 'honor linked issues', default: false

  o.on '--help', 'print the help' do
    puts o
    exit
  end
end

def git_repo(url, name, opts)
  begin
    git_repo = Git.open(name)
  rescue ArgumentError
    uri = Addressable::URI.parse("#{url}.git")
    uri.user = opts[:gitusername]
    uri.password = opts[:gitpassword]
    git_repo = Git.clone(uri, name)
  end
  git_repo.reset_hard
  git_repo.fetch
  git_repo.branch("#{opts[:release]}-#{opts[:postfix]}").checkout
  git_repo.branch(opts[:source]).checkout
  git_repo.pull
  if opts[:clean]
    git_repo.branch("#{opts[:release]}-#{opts[:postfix]}").delete
    git_repo.chdir do
      `git push origin :#{opts[:release]}-#{opts[:postfix]}`
    end
  end
  git_repo.branch("#{opts[:release]}-#{opts[:postfix]}").checkout
  git_repo.merge(opts[:source],
                 "CI: merge source branch #{opts[:source]} to release #{opts[:release]}-#{opts[:postfix]} ")
  git_repo
end

options = { auth_type: :basic }.merge(opts.to_hash)
client = JIRA::Client.new(options)

release = client.Issue.find(opts[:release])

if release.deploys.any? && !opts[:ignorelinks]
  puts 'linked'
  issues = release.deploys
else
  puts 'fresh'
  issues = client.Issue.jql('(project = Accounting AND status = Passed OR '\
    'status in ("Merge ready", "In Release")) AND project not in '\
    '("Servers & Services", Hotels) ORDER BY priority DESC, issuekey DESC')
  issues.each do |issue|
    puts issue.key
    issue.link
  end
end

badissues = {}
repos = {}

puts issues.size
issues.each do |issue|
  puts issue.key
  goodissue = false
  badissue = false
  if issue.related['pullRequests'].empty?
    body = "CI: [~#{issue.assignee.key}] No pullrequest here"
    badissues[:absent] = [] unless badissues.key?(:absent)
    badissues[:absent].push(key: issue.key, body: body)
    issue.post_comment body
    badissue = true
  else
    issue.related['pullRequests'].each do |pullrequest|
      if pullrequest['status'] != 'OPEN'
        puts "Not processing not OPEN PR #{pullrequest['url']}"
        next
      end
      if pullrequest['source']['branch'].match "^#{issue.key}"
        issue.related['branches'].each do |branch|
          if branch['url'] == pullrequest['source']['url']

            repo_name = branch['repository']['name']
            repo_url = branch['repository']['url']
            repos[repo_name] ||= { url: repo_url, branches: [] }
            repos[repo_name][:repo_base] ||= git_repo(repo_url, repo_name, opts)
            repos[repo_name][:branches].push(issue: issue,
                                             pullrequest: pullrequest,
                                             branch: branch)
            repo_path = repos[repo_name][:repo_base]
            begin
              merge_message = "CI: merge branch #{branch['name']} to release "\
                              " #{opts[:release]}.  (pull request #{pullrequest['id']}) "
              repo_path.merge("origin/#{branch['name']}", merge_message)
              puts "#{branch['name']} merged"
              goodissue = true
            rescue Git::GitExecuteError => e
              body = <<-BODY
              CI: Error while merging to release #{opts[:release]}
              [~#{issue.assignee.key}]
              Repo: #{repo_name}
              Author: #{pullrequest['author']['name']}
              PR: #{pullrequest['url']}
              {noformat:title=Ошибка}
              Error #{e}
              {noformat}
              BODY
              if opts[:push]
                issue.post_comment body
                badissue = true
              end
              badissues[:unmerged] = [] unless badissues.key?(:unmerged)
              badissues[:unmerged].push(key: issue.key, body: body)
              repo_path.reset_hard
              puts "\n"
            end
          end
        end
      else
        body = "CI: [~#{issue.assignee.key}] PR: #{pullrequest['id']}"\
               " #{pullrequest['source']['branch']} не соответствует"\
               " имени задачи #{issue.key}"
        badissues[:badname] = [] unless badissues.key?(:badname)
        badissues[:badname].push(key: issue.key, body: body)
      end
    end
  end

  if !badissue && issue.status.name != 'In Release' && goodissue
    issue.transition 'Merge to release'
  elsif badissue
    issue.transition 'Merge Fail'
  end
end

puts 'Repos:'
repos.each do |name, repo|
  puts name
  if opts[:push]
    local_repo = repo[:repo_base]
    local_repo.push('origin', "#{opts[:release]}-#{opts[:postfix]}")
  end
end

puts 'Not Merged'
badissues.each_pair do |status, keys|
  puts "#{status}: #{keys.size}"
  keys.each { |i| puts i[:key] }
end
