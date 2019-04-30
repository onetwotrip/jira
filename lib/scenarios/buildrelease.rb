module Scenarios
  ##
  # BuildRelease scenario
  class BuildRelease
    attr_reader :opts

    def initialize(opts)
      @opts = opts
    end

    def run(is_only_one_branch = false) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize, Metrics/LineLength
      LOGGER.info "Build release #{opts[:release]}"

      options = { auth_type: :basic }.merge(opts.to_hash)
      client  = JIRA::Client.new(options)
      release = client.Issue.find(opts[:release])

      release.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Запущено формирование -pre веток (!)
        Ожидайте сообщение о завершении
      {panel}
      BODY

      begin
        if release.linked_issues('deployes').empty? || opts[:ignorelinks]
          LOGGER.warn "I can't found ticket linked with type 'deploys'"
          release.post_comment <<-BODY
          {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
            У релизного тикета нет тикетов с линком 'deploys'
            Сборка остановлена
          {panel}
          BODY
          exit(1)
        end

        # Unlink blocked issues:
        #   1) Get deployes issues of release
        #   2) Check status of blocked tasks of issues.
        #   3) If task hasn't necessary status - unlink issue from release
        good_statuses = %w[Done Closed Fixed Rejected]
        release.issuelinks.each do |issuelink|
          if issuelink.type.name == 'Deployed' &&
            issuelink.outwardIssue && # rubocop:disable Layout/MultilineOperationIndentation
            issuelink.outwardIssue.linked_issues('is blocked by').any? { |i| !good_statuses.include? i.status.name } # rubocop:disable Layout/MultilineOperationIndentation, Metrics/LineLength
            comment = "#{issuelink.outwardIssue.key} blocked. Unlink from release #{release.key}"
            release.post_comment comment
            issuelink.outwardIssue.post_comment comment
            issuelink.delete
            LOGGER.fatal comment
          end
          # Unlink issue with more than one product branches. Test is skipped
          next unless is_only_one_branch
          branches      = issuelink.outwardIssue.branches
          branches_list = []
          branches.each do |branch|
            branches_list << branch.repo_slug
          end
          next unless (branches_list.uniq - ['avia_api_rspec', 'back-components']).size > 1
          comment = "Remove issue #{issuelink.outwardIssue.key} from release. Reason: issue has more than 1 product branch"
          release.post_comment comment
          issuelink.delete
          LOGGER.fatal comment
        end

        badissues = {}
        repos     = {}

        pre_release_branch = "#{opts[:release]}-#{opts[:postfix]}"
        release_branch     = "#{opts[:release]}-release"
        source             = opts[:source]
        delete_branches    = []
        delete_branches << pre_release_branch

        # Get release branch if exist for feature deleting
        release.related['branches'].each do |branch|
          if branch['name'].include?(release_branch)
            puts "Found release branch: #{branch['name']}. It's going to be delete".red
            delete_branches << branch['name']
          end
        end

        LOGGER.info "Number of issues: #{release.linked_issues('deployes').size}"
        release.linked_issues('deployes').each do |issue| # rubocop:disable Metrics/BlockLength
          LOGGER.info "Working on #{issue.key}"
          issue.transition 'Not merged' if issue.has_transition? 'Not merged'
          has_merges = false
          merge_fail = false
          if issue.related['pullRequests'].empty?
            body               = "CI: [~#{issue.assignee.key}] No pullrequest here"
            badissues[:absent] = [] unless badissues.key?(:absent)
            badissues[:absent].push(key: issue.key, body: body)
            issue.post_comment body
            merge_fail = true
          else
            issue.related['pullRequests'].each do |pullrequest| # rubocop:disable Metrics/BlockLength
              if pullrequest['status'] != 'OPEN'
                msg = "Not processing not OPEN PR #{pullrequest['url']}"
                LOGGER.fatal msg
                issue.post_comment msg
                next
              end
              if pullrequest['source']['branch'].match "^#{issue.key}"
                # Need to remove follow each-do line.
                # Branch name/url can be obtained from PR.
                issue.related['branches'].each do |branch| # rubocop:disable Metrics/BlockLength
                  next unless branch['url'] == pullrequest['source']['url']

                  repo_name = branch['repository']['name']
                  repo_url  = branch['repository']['url']
                  # Example of repos variable:
                  # {
                  #   "RepoName" => {
                  #     :url=>"https://github.com/Vendor/RepoName/",
                  #     :branches=>[],
                  #     :repo_base=> Git::Object
                  #   },
                  #   ...
                  # }
                  repos[repo_name]             ||= { url: repo_url, branches: [] }
                  repos[repo_name][:repo_base] ||= git_repo(repo_url,
                                                            delete_branches: delete_branches)
                  repos[repo_name][:branches].push(issue:       issue,
                                                   pullrequest: pullrequest,
                                                   branch:      branch)
                  repo_path = repos[repo_name][:repo_base]
                  repo_path.checkout('master')
                  # Merge master to pre_release_branch (ex OTT-8703-pre)
                  prepare_branch(repo_path, source, pre_release_branch, opts[:clean])
                  # enable 'ours' merge strategy
                  repo_path.chdir do
                    `git config merge.ours.driver true`
                  end
                  begin
                    merge_message = "CI: merge branch #{branch['name']} to release "\
                                  " #{opts[:release]}.  (pull request #{pullrequest['id']}) "
                    # Merge origin/branch (ex FE-429-Auth-Popup-fix) to pre_release_branch (ex OTT-8703-pre)
                    repo_path.merge("origin/#{branch['name']}", merge_message)
                    LOGGER.info "#{branch['name']} merged"
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
                  Замержите мастер в ветку #{branch['name']} .
                  Затем замержите ветку #{branch['name']} в ветку релиза #{pre_release_branch}.
                  После этого переведите задачу в статус *In Release*
                    BODY
                    if opts[:push] # rubocop:disable Metrics/BlockNesting
                      issue.post_comment body
                      merge_fail = true
                    end
                    badissues[:unmerged] = [] unless badissues.key?(:unmerged) # rubocop:disable Metrics/BlockNesting
                    badissues[:unmerged].push(key: issue.key, body: body)
                    repo_path.reset_hard
                    puts "\n"
                  end
                end
              else
                body                = "CI: [~#{issue.assignee.key}] PR: #{pullrequest['id']}"\
                     " #{pullrequest['source']['branch']} не соответствует"\
                     " имени задачи #{issue.key}"
                badissues[:badname] = [] unless badissues.key?(:badname)
                badissues[:badname].push(key: issue.key, body: body)
              end
            end
          end

          if !merge_fail && has_merges
            issue.transition 'Merge to release'
          elsif merge_fail
            issue.transition 'Merge Fail'
            LOGGER.fatal "#{issue.key} was not merged!"
          end
        end

        LOGGER.info 'Repos:' unless repos.empty?
        repos.each do |name, repo|
          LOGGER.info "Push '#{pre_release_branch}' to '#{name}' repo"
          next unless opts[:push]
          local_repo = repo[:repo_base]
          local_repo.push('origin', pre_release_branch)
          local_repo.checkout('master')
        end

        LOGGER.fatal 'Not Merged:' unless badissues.empty?
        badissues.each_pair do |status, keys|
          LOGGER.fatal "#{status}: #{keys.size}"
          keys.each { |i| LOGGER.fatal i[:key] }
        end
      rescue StandardError => e
        release.post_comment <<-BODY
        {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
         Не удалось собрать -pre ветки (x)
         Подробности в логе таски https://jenkins.twiket.com/view/RELEASE/job/build_release/
        {panel}
        BODY
        LOGGER.error "Не удалось собрать -pre ветки, ошибка: #{e.message}, трейс:\n\t#{e.backtrace.join("\n\t")}"
        exit(1)
      end

      release.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Сборка -pre веток завершена (/)
      {panel}
      BODY
    end
  end
end
