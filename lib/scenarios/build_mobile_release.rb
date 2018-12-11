module Scenarios

  # Build mobile release
  # From develop
  # PR to develop and master
  class BuildMobileRelease

    def run # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
      LOGGER.info("Build mobile release from ticket #{SimpleConfig.jira.issue}")

      # Start
      jira    = JIRA::Client.new SimpleConfig.jira.to_h
      release = jira.Issue.find(SimpleConfig.jira.issue)
      # release.post_comment <<-BODY
      # {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
      #   Запущено формирование -pre веток(!)
      #   Ожидайте сообщение о завершении
      # {panel}
      # BODY

      begin
        # Check link type
        if release.linked_issues('deployes').empty?
          LOGGER.warn "I can't found tickets linked with type 'deployes'. Please check tickets link type"
        end

        badissues = {}
        repos     = {}

        pre_release_branch = "#{release}-pre"
        release_branch     = "#release/#{release}"
        source             = 'develop'
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

        # Check linked issues for merger PR
        release.linked_issues('deployes').each do |issue| # rubocop:disable Metrics/BlockLength
          LOGGER.info "Working on #{issue.key}"
          has_merges = false
          merge_fail = false
          if issue.related['pullRequests'].empty? && !issue.related['branches'].empty?
            body               = "There is no pullrequest, but there is branhes. I'm afraid of change is not at develop"
            badissues[:absent] = [] unless badissues.key?(:absent)
            badissues[:absent].push(key: issue.key, body: body)
            issue.post_comment body
            merge_fail = true
          else
            issue.related['pullRequests'].each do |pullrequest|
              if pullrequest['status'] != 'MERGED'
                LOGGER.fatal 'Not merged PR found'
                issue.post_comment 'Not merged PR found. Please merge it into develop and update -pre branch before go next step'
                merge_fail = true
                next
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

      end
      # release.post_comment <<-BODY
      # {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
      #   Сборка -pre веток завершена (/)
      # {panel}
      # BODY
    end
  end
end