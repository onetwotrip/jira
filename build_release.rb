require 'simple_config'
require 'colorize'
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
  o.string '-u', '--username', 'username', default: SimpleConfig.jira.username
  o.string '-p', '--password', 'password', default: SimpleConfig.jira.password
  o.string '--site', 'site', default: SimpleConfig.jira.site
  o.string '--context_path', 'context path', default: ''
  o.string '--release', 'release', default: 'OTT-4749'
  o.string '--source', 'source branch', default: 'master'
  o.string '--postfix', 'branch name postfix', default: 'pre'

  o.string '-gu', '--gitusername', 'username', default: 'jenkins_ott'
  o.string '-gp', '--gitpassword', 'password', default: SimpleConfig.jira.password

  o.bool '--push', 'push to remote', default: false
  o.bool '--clean', 'clean local and remote branches', default: false
  o.bool '--dryrun', 'do not post comments to Jira', default: false
  o.bool '--ignorelinks', 'honor linked issues', default: false

  o.on '--help', 'print the help' do
    puts o
    exit
  end
end

puts "Build release #{opts[:release]}".green

options = { auth_type: :basic }.merge(opts.to_hash)
client = JIRA::Client.new(options)
release = client.Issue.find(opts[:release])

unless release.deploys.any? && !opts[:ignorelinks]
  puts 'Deploys issue not found or ignored. Force JQL.'
  client.Issue.jql(
    %[(status in ("Merge ready")
    OR (status in ( "In Release")
    AND issue in linkedIssues(#{release.key},"deployes")))
    AND (Modes is Empty OR modes != "Manual Deploy")
    AND project not in (#{SimpleConfig.jira.excluded_projects.to_sql})
    ORDER BY priority DESC, issuekey DESC]
  ).each(&:link)
end

issues = release.all_deploys do |issue|
  issue.tags?(SimpleConfig.jira.tags.field, SimpleConfig.jira.tags.deploy)
end

badissues = {}
repos = {}

pre_release_branch = "#{opts[:release]}-#{opts[:postfix]}"
release_branch = "#{opts[:release]}-release"
source = opts[:source]

# rubocop:disable Metrics/BlockNesting
puts "Number of issues: #{issues.size}"
issues.each do |issue|
  puts "Working on #{issue.key}".green
  issue.transition 'Not merged' if issue.has_transition? 'Not merged'
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
        puts "Not processing not OPEN PR #{pullrequest['url']}".red
        next
      end
      if pullrequest['source']['branch'].match "^#{issue.key}"
        # Need to remove follow each-do line.
        # Branch name/url can be obtained from PR.
        issue.related['branches'].each do |branch|
          next unless branch['url'] == pullrequest['source']['url']

          repo_name = branch['repository']['name']
          repo_url = branch['repository']['url']
          # Example of repos variable:
          # {
          #   "RepoName" => {
          #     :url=>"https://github.com/Vendor/RepoName/",
          #     :branches=>[],
          #     :repo_base=> Git::Object
          #   },
          #   ...
          # }
          repos[repo_name] ||= { url: repo_url, branches: [] }
          repos[repo_name][:repo_base] ||= git_repo(repo_url,
                                                    repo_name,
                                                    delete_branches: [pre_release_branch, release_branch])
          repos[repo_name][:branches].push(issue: issue,
                                           pullrequest: pullrequest,
                                           branch: branch)
          repo_path = repos[repo_name][:repo_base]
          repo_path.checkout('master')
          # Merge master to pre_release_branch (ex OTT-8703-pre)
          prepare_branch(repo_path, source, pre_release_branch, opts[:clean])
          begin
            merge_message = "CI: merge branch #{branch['name']} to release "\
                            " #{opts[:release]}.  (pull request #{pullrequest['id']}) "
            # Merge origin/branch (ex FE-429-Auth-Popup-fix) to pre_release_branch (ex OTT-8703-pre)
            repo_path.merge("origin/#{branch['name']}", merge_message)
            puts "#{branch['name']} merged".green
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
            Замержите ветку #{branch['name']} в ветку релиза #{pre_release_branch}.
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

puts 'Repos:'.green
repos.each do |name, repo|
  puts "Push '#{pre_release_branch}' to '#{name}' repo".green
  if opts[:push]
    local_repo = repo[:repo_base]
    local_repo.push('origin', pre_release_branch)
  end
end

puts 'Not Merged'.red
badissues.each_pair do |status, keys|
  puts "#{status}: #{keys.size}"
  keys.each { |i| puts i[:key] }
end
