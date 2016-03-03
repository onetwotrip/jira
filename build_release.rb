require 'simple_config'
require 'jira'
require 'pp'
require 'git'
require 'slop'
require 'json'
require 'rest-client'
require 'addressable/uri'
require './lib/issue'
require_relative 'lib/repo'

opts = Slop.parse do |o|
  # Connection settings
  o.string '-u', '--username', 'username', default: SimpleConfig.jira.user
  o.string '-p', '--password', 'password', default: SimpleConfig.jira.pass
  o.string '--site', 'site', default: SimpleConfig.jira.site
  o.string '--context_path', 'context path', default: ''
  o.string '--release', 'release', default: 'OTT-4749'
  o.string '--source', 'source branch', default: 'master'
  o.string '--postfix', 'branch name postfix', default: 'pre'

  o.string '-gu', '--gitusername', 'username', default: 'jenkins_ott'
  o.string '-gp', '--gitpassword', 'password', default: SimpleConfig.jira.pass

  o.bool '--push', 'push to remote', default: false
  o.bool '--clean', 'clean local and remote branches', default: false
  o.bool '--dryrun', 'do not post comments to Jira', default: false
  o.bool '--ignorelinks', 'honor linked issues', default: false

  o.on '--help', 'print the help' do
    puts o
    exit
  end
end

options = { auth_type: :basic }.merge(opts.to_hash)
client = JIRA::Client.new(options)

release = client.Issue.find(opts[:release])

if release.deploys.any? && !opts[:ignorelinks]
  puts 'linked'
  issues = release.deploys
  issues.each do |issue|
    puts issue.key
    issue.transition 'Not merged' if issue.has_transition? 'Not merged'
  end
else
  puts 'fresh'
  issues = client.Issue.jql(%[(project = Accounting AND status = Passed OR
    status in ("Merge ready") OR (status in ( "In Release")
    AND issue in linkedIssues(#{release.key},"deployes")))
    AND project not in ("Servers & Services", Hotels, "Russian Railroad")
    ORDER BY priority DESC, issuekey DESC])
  issues.each do |issue|
    puts issue.key
    issue.transition 'Not merged' if issue.has_transition? 'Not merged'
    issue.link
  end
end

badissues = {}
repos = {}

release_branch = "#{opts[:release]}-#{opts[:postfix]}"
source = opts[:source]

# rubocop:disable Metrics/BlockNesting
issues = release.deploys
puts issues.size
issues.each do |issue|
  puts issue.key
  has_merges = false
  merge_fail = false
  if issue.related['pullRequests'].empty?
    body = "CI: [~#{issue.assignee.key}] No pullrequest here"
    badissues[:absent] = [] unless badissues.key?(:absent)
    badissues[:absent].push(key: issue.key, body: body)
    issue.post_comment body
    merge_fail = true
  else
    issue.related['pullRequests'].each do |pullrequest|
      if pullrequest['status'] != 'OPEN'
        puts "Not processing not OPEN PR #{pullrequest['url']}"
        next
      end
      if pullrequest['source']['branch'].match "^#{issue.key}"
        issue.related['branches'].each do |branch|
          next unless branch['url'] == pullrequest['source']['url']

          repo_name = branch['repository']['name']
          repo_url = branch['repository']['url']
          repos[repo_name] ||= { url: repo_url, branches: [] }
          repos[repo_name][:repo_base] ||= git_repo(repo_url, repo_name, opts)
          repos[repo_name][:branches].push(issue: issue,
                                           pullrequest: pullrequest,
                                           branch: branch)
          repo_path = repos[repo_name][:repo_base]
          prepare_branch(repo_path, source, release_branch, opts[:clean])
          begin
            merge_message = "CI: merge branch #{branch['name']} to release "\
                            " #{opts[:release]}.  (pull request #{pullrequest['id']}) "
            repo_path.merge("origin/#{branch['name']}", merge_message)
            puts "#{branch['name']} merged"
            has_merges = true
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
            Замержите ветку #{branch['name']} в ветку релиза #{release_branch}.
            После этого сообщите своему тимлиду, чтобы он перевёл задачу в статус in Release
            BODY
            if opts[:push]
              issue.post_comment body
              merge_fail = true
            end
            badissues[:unmerged] = [] unless badissues.key?(:unmerged)
            badissues[:unmerged].push(key: issue.key, body: body)
            repo_path.reset_hard
            puts "\n"
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

  if !merge_fail && issue.status.name != 'In Release' && has_merges
    issue.transition 'Merge to release'
  elsif merge_fail
    issue.transition 'Merge Fail'
  end
end

puts 'Repos:'
repos.each do |name, repo|
  puts name
  if opts[:push]
    local_repo = repo[:repo_base]
    local_repo.push('origin', release_branch)
  end
end

puts 'Not Merged'
badissues.each_pair do |status, keys|
  puts "#{status}: #{keys.size}"
  keys.each { |i| puts i[:key] }
end
