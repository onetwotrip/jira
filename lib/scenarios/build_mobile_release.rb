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
          LOGGER.fatal "I can't found tickets linked with type 'deployes'. Please check tickets link type"
          exit(1)
        end

        LOGGER.info "Number of issues: #{release.linked_issues('deployes').size}"

        badissues = {}

        # Check linked issues for merged PR
        release.linked_issues('deployes').each do |issue| # rubocop:disable Metrics/BlockLength
          LOGGER.info "Working on #{issue.key}"
          has_merges = false
          merge_fail = false
          valid_pr = []
          # Check ticket status
          LOGGER.info "Ticket #{issue.key} has status: #{issue.status.name}, but should 'Merge ready'" if issue.status.name != 'Merge ready'

          # Check PR exist in ticket
          if issue.related['pullRequests'].empty?
            if !issue.related['branches'].empty?
              body               = "#{issue.key}: There is no pullrequest, but there is branhes. I'm afraid of changes are not at develop"
              badissues[:absent] = [] unless badissues.key?(:absent)
              badissues[:absent].push(key: issue.key, body: body)
              LOGGER.fatal body
              issue.post_comment body
              merge_fail = true
            else
              LOGGER.info "#{issue.key}: ticket without PR and branches"
              has_merges = true
              next
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
                LOGGER.info "#{issue.key}: Found PR with doesn't contains task number"
                badissues[:badname] = [] unless badissues.key?(:badname)
                badissues[:badname].push(key: issue.key, body: "Found PR with doesn't contains task number")
              end
            end
            # if ticket doesn't have valid pr (valid means contain issue number)
            unless valid_pr.include?(true)
              body               = "#{issue.key}: There is no pullrequest contains issue number. I'm afraid of changes from ticket are not at develop"
              badissues[:absent] = [] unless badissues.key?(:absent)
              badissues[:absent].push(key: issue.key, body: body)
              LOGGER.fatal body
              #issue.post_comment body
              merge_fail = true
            end
          end

          # Change issue status
          if !merge_fail && has_merges
            issue.transition 'Merge to release'
          elsif merge_fail
            #issue.transition 'Merge Fail'
            LOGGER.fatal "#{issue.key} was not merged!"
          end
        end

        LOGGER.info 'Delete old branches before go next'
        # Clean old release branch if exist
        release_branch     = "#release/#{release}"
        pre_release_branch = "#{release}-pre"
        delete_branches    = []
        delete_branches << pre_release_branch

        release.related['branches'].each do |branch|
          if branch['name'].include?(release_branch)
            puts "Found release branch: #{branch['name']}. It's going to be delete".red
            delete_branches << branch['name']
          end
        end

        # Create -pre branch and with PR to develop and master
        # TODO

        repos = {}

        source = 'develop'

        # Add labels
        # TODO





      end
      # release.post_comment <<-BODY
      # {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
      #   Сборка -pre веток завершена (/)
      # {panel}
      # BODY
    end
  end
end