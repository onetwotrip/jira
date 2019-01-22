module Scenarios
  # Build mobile release
  # From develop
  # PR to develop and master
  class BuildMobileRelease
    attr_accessor :opts, :repo_prepare

    def initialize(opts)
      @opts         = opts
      @repo_prepare = false
    end

    def run # rubocop:disable Metrics/PerceivedComplexity, Metrics/MethodLength
      LOGGER.info("Build mobile release from ticket #{opts[:release]}")

      # Start
      options = { auth_type: :basic }.merge(opts.to_hash)
      jira    = JIRA::Client.new(options)
      release = jira.Issue.find(opts[:release])
      release.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Запущено формирование -pre веток(!)
        Ожидайте сообщение о завершении
      {panel}
      BODY

      begin
        @fix_version = release.fields['fixVersions']
        # Check fix Version exist
        if @fix_version.empty?
          release.post_comment <<-BODY
            {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F04D2A|bgColor=#F1F3F1}
              У релизного тикета не выставлен 'Fix Version/s'(!)
              Сборка прекращена. Исправьте проблему и перезапустите сборку
            {panel}
          BODY
          LOGGER.error "У релизного тикета не выставлен 'Fix Version/s'"
          exit(1)
        end

        # Clean old release branch if exist
        release_branch     = "#release/#{opts[:release]}"
        pre_release_branch = "#{opts[:release]}-pre"
        delete_branches    = []
        delete_branches << pre_release_branch

        # Get release branch if exist for feature deleting
        release.related['branches'].each do |branch|
          if branch['name'].include?(release_branch)
            puts "Found release branch: #{branch['name']}. It's going to be delete".red
            delete_branches << branch['name']
          end
        end

        # Check link type
        if release.linked_issues('deployes').empty?
          LOGGER.fatal "I can't found tickets linked with type 'deployes'. Please check tickets link type"
          exit(1)
        end

        LOGGER.info "Number of issues: #{release.linked_issues('deployes').size}"

        badissues    = {}
        repos        = {}

        # Check linked issues for merged PR
        release.linked_issues('deployes').each do |issue| # rubocop:disable Metrics/BlockLength
          LOGGER.info "Working on #{issue.key}"
          has_merges = false
          merge_fail = false
          valid_pr   = []
          # Check ticket status
          LOGGER.info "Ticket #{issue.key} has status: #{issue.status.name}, but should 'Merge ready'" if issue.status.name != 'Merge ready'

          # Check PR exist in ticket
          if issue.related['pullRequests'].empty?
            if !issue.related['branches'].empty?
              body               = "#{issue.key}: There is no pullrequest, but there is branhes. I'm afraid of changes are not at develop"
              badissues[:absent] = [] unless badissues.key?(:absent)
              badissues[:absent].push(issue.key)
              LOGGER.fatal body
              issue.post_comment body
              merge_fail = true
            else
              LOGGER.info "#{issue.key}: ticket without PR and branches"
              has_merges = true
            end
          else
            valid_pr << false
            issue.related['pullRequests'].each do |pullrequest|
              # Check PR match with ticket number
              if pullrequest['source']['branch'].include? issue.key
                valid_pr << true
                # Check PR status: open, merged
                if pullrequest['status'] != 'MERGED'
                  LOGGER.fatal "#{issue.key}: PR with task number not merged in develop"
                  issue.post_comment 'Not merged PR found. Please merge it into develop and update -pre branch before go next step'
                  merge_fail = true
                else
                  LOGGER.info "#{issue.key}: PR already merged in develop"
                end
              else
                LOGGER.warn "#{issue.key}: Found PR with doesn't contains task number"
                badissues[:badname] = [] unless badissues.key?(:badname)
                badissues[:badname].push(issue.key)
              end
            end
            # if ticket doesn't have valid pr (valid means contain issue number)
            unless valid_pr.include?(true)
              body               = "#{issue.key}: There is no pullrequest contains issue number. I'm afraid of changes from ticket are not at develop" # rubocop:disable Metrics/LineLength
              badissues[:absent] = [] unless badissues.key?(:absent)
              badissues[:absent].push(issue.key)
              LOGGER.fatal body
              issue.post_comment body
              merge_fail = true
            end
          end

          # Change issue status
          if !merge_fail && has_merges
            issue.transition 'Merge to release'
          elsif merge_fail
            issue.transition 'Merge Fail'
            LOGGER.fatal "#{issue.key} was not merged!"
          end

          # Prepare repo object
          @repo_obj = prepare_repos(issue) unless repo_prepare
        end

        # Prepare develop branch to create -pre
        repos[@repo_obj[:name]] = { url: @repo_obj[:url], branches: [] }
        repos[@repo_obj[:name]][:repo_base] ||= git_repo(@repo_obj[:url], delete_branches: delete_branches)

        repo_path = repos[@repo_obj[:name]][:repo_base]

        repo_path.checkout('master')
        prepare_branch(repo_path, 'develop', pre_release_branch, opts[:clean])

        # Create -pre branch and with PR to develop and master
        if opts[:push]
          LOGGER.info 'Repos:' unless repos.empty?
          repos.each do |name, repo|
            LOGGER.info "Push '#{pre_release_branch}' to '#{name}' repo"
            LOGGER.info 'Push to remote'
            local_repo = repo[:repo_base]
            local_repo.push('origin', pre_release_branch)
            tag = "release/#{@fix_version.first['name']}"
            local_repo.add_tag(tag, pre_release_branch, messsage: 'Add TestTag', f: true)
            local_repo.push('origin', "refs/tags/#{tag}", f: true)
          end
        end

        LOGGER.fatal 'Not Merged:' unless badissues.empty?
        badissues.each_pair do |status, keys|
          LOGGER.fatal "#{status}: #{keys.size}"
          keys.uniq.each { |i| LOGGER.fatal i }
        end
      rescue StandardError => e
        LOGGER.error "Не удалось собрать -pre ветки, ошибка: #{e.message}, трейс:\n\t#{e.backtrace.join("\n\t")}"
        exit(1)
      end
      release.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#10B924|bgColor=#F1F3F1}
        Сборка -pre веток завершена (/)
      {panel}
      BODY
    end

    def prepare_repos(issue)
      repositories = %w(ios-12trip android_ott) # rubocop:disable Style/PercentLiteralDelimiters
      issue.related['branches'].each do |branch|
        next unless branch['name'].include? issue.key

        repo_name = branch['repository']['name']
        next unless repositories.include? repo_name
        repo_url          = branch['repository']['url']
        self.repo_prepare = true
        return { url: repo_url, name: repo_name }
      end
    end
  end
end
