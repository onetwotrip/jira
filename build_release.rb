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
  o.string '--contextpath', 'context path', default: ''
  o.string '--release', 'release', default: 'OTT-4487'
  o.string '--source', 'source branch', default: 'master'
  o.string '--postfix', 'branch name postfix', default: 'pre'

  o.string '-gu', '--gitusername', 'username', default: 'jenkins_ott'
  o.string '-gp', '--gitpassword', 'password', default: '9E=mCqM*'

  o.bool '--push', 'push to remote', default: false
  o.bool '--clean', 'clean local and remote branches', default: false
  o.bool '--dryrun', 'post comments to Jira', default: false

  o.on '--help', 'print the help' do
    puts o
    exit
  end
end

options = { username: opts[:username],
            password: opts[:password],
            site:     opts[:site],
            context_path: opts[:contextpath],
            auth_type: :basic
          }

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

client = JIRA::Client.new(options)

issues = client.Issue.jql('(project = Accounting AND status = Passed OR '\
  'status in ("Merge ready", "In Release")) AND project not in ("Servers & Services", Hotels) ORDER BY priority DESC, issuekey DESC')
badissues = []
repos = {}

puts issues.size
issues.each do |issue|
  goodissue = false
  badissue = false
  issue.opts_setter opts
  issue.related.each do |related_data|
    if related_data['pullRequests'].empty?
      badissues.push(key: issue.key, errorcode: :absent)
      issue.post_comment "CI: [~#{issue.assignee.key}] No pullrequest here"
      badissue = true
    else
      related_data['pullRequests'].each do |pullrequest|
        if pullrequest['status'] != 'OPEN'
          puts "Not processing not OPEN PR #{pullrequest['url']}"
          next
        end
        # if pullrequest['reviewers'].empty?
        #   puts "Not processing unapproved PR #{pullrequest['url']}"
        #   issue.post_comment "CI: [~#{issue.assignee.key}] Pullrequest #{pullrequest['url']} must be approved by teamlead"
        #   badissue = true
        #   next
        # end
        if pullrequest['source']['branch'].match "^#{issue.key}"
          related_data['branches'].each do |branch|
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
                repo_path.merge("origin/#{branch['name']}", "CI: merge branch #{branch['name']} to release #{opts[:release]}. PR: ##{pullrequest['id']} ")
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
                issue.post_comment body if opts[:push]
                badissues.push(key: issue.key, body: body, errorcode: :unmerged)
                repo_path.reset_hard
                badissue = true
                puts "\n"
              end
            end
          end
        else
          body = "CI: [~#{issue.assignee.key}] PR: #{pullrequest['id']} #{pullrequest['source']['branch']} не соответствует имени задачи #{issue.key}"
          issue.post_comment body
          badissues.push(key: issue.key, body: body, errorcode: :badname)
          badissue = true
          # TODO: Notify Jira, Notify Slack
        end
      end
    end
  end
  issue.link
  if !badissue || issue.status == 'In Release'
    issue.transition 'Merge to release'
  elsif badissue
    issue.transition 'Merge Fail' if badissue
  end
end

puts 'Not Merged'
badissues.each do |issue|
  pp issue
end

puts 'Repos:'
repos.each do |name, repo|
  puts name
  if opts[:push]
    local_repo = repo[:repo_base]
    local_repo.push('origin', "#{opts[:release]}-#{opts[:postfix]}")
  end
end
