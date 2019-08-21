module Scenarios
  ##
  # PostactionRelease scenario
  class PostactionMobileRelease
    def with(instance, &block)
      instance.instance_eval(&block)
      instance
    end

    def run
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      # noinspection RubyArgCount
      issue = jira.Issue.find(SimpleConfig.jira.issue)

      is_error = false

      LOGGER.info "Try to get all PR in status OPEN from #{issue.key}"
      pullrequests = issue.pullrequests(SimpleConfig.git.to_h)
                          .filter_by_status('OPEN')
                          .filter_by_source_url(SimpleConfig.jira.issue)

      unless pullrequests.valid?
        issue.post_comment p("ReviewRelease: #{pullrequests.valid_msg}")
        exit
      end

      LOGGER.info "Found #{pullrequests.prs.size} PR in status OPEN"

      @fix_version = issue.fields['fixVersions']
      # If this are IOS or ANDROID project we need to add tag on merge commit
      tag_enable = issue.key.include?('IOS') || issue.key.include?('ADR')
      # Work with release branch
      pullrequests.each do |pr| # rubocop:disable Metrics/BlockLength
        LOGGER.info 'Try to find release branch'
        next unless pr.pr['name'].include?('release')
        begin
          LOGGER.info "Found release PR: #{pr.pr['source']['branch']}"
          local_repo = pr.repo

          # Add tag on merge commit
          if tag_enable
            tag = @fix_version.first['name']
            LOGGER.info "Try to add tag #{tag} to #{pr.pr['destination']['branch']}"
            local_repo.add_tag(tag, pr.pr['destination']['branch'], messsage: 'Add tag to merge commit', f: true)
            local_repo.push('origin', "refs/tags/#{tag}", f: true)
            LOGGER.info 'Success!'
          end
          LOGGER.info "Try to merge #{pr.src.branch} in #{pr.dst}/#{pr.dst.branch}"
          local_repo.push('origin', pr.pr['destination']['branch'])
          LOGGER.info 'Success!'

          # IF repo is `ios-12trip` so make PR from updated master to develop
          if pr.pr['destination']['url'].include?('ios-12trip')
            LOGGER.warn 'Try to make PR from master to develop'
            with local_repo do
              checkout('master')
              pull
              create_pullrequest(
                SimpleConfig.bitbucket[:username],
                SimpleConfig.bitbucket[:password],
                'master',
                'develop'
              )
            end
            LOGGER.info 'Make success PR!'
          end
        rescue Git::GitExecuteError => e
          is_error = true
          LOGGER.fatal e.message
          if e.message.include?('Merge conflict')
            issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  Не удалось замержить release PR: #{pr.pr['url']}
                  *Причина:* Merge conflict
              {panel}
            BODY
          else
            issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  Не удалось замержить release PR: #{pr.pr['url']}
                  *Причина:* #{e.message}
              {panel}
            BODY
          end
          next
        end
      end

      # Work with feature branch, if exist
      LOGGER.info 'Try to get all PR in status OPEN'
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      pullrequests = issue.pullrequests(SimpleConfig.git.to_h)
                          .filter_by_status('OPEN')
                          .filter_by_source_url(SimpleConfig.jira.issue)
      LOGGER.info "Found #{pullrequests.prs.size} PR in status OPEN after release branch was merged"
      pullrequests.each do |pr|
        LOGGER.info 'Try to find feature PR for decline'
        next unless pr.pr['name'].include?('feature')
        begin
          LOGGER.info "Found feature PR: #{pr.pr['source']['branch']}"
          local_repo = pr.repo

          # Decline PR if destination branch is develop
          LOGGER.warn 'Try to decline PR to develop'
          with local_repo do
            decline_pullrequest(
              SimpleConfig.bitbucket[:username],
              SimpleConfig.bitbucket[:password],
              pr.pr['id']
            )
          end
          LOGGER.info 'Success declined PR'
        rescue Git::GitExecuteError => e
          is_error = true
          LOGGER.fatal e.message
          issue.post_comment <<-BODY
            {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                Не удалось отменить PR: #{pr.pr['url']}
                *Причина:* #{e.message}
            {panel}
          BODY
          next
        end
      end

      # Work with tickets
      issue.linked_issues('deployes').each do |subissue|
        # Transition to DONE
        subissue.transition 'To master' if subissue.get_transition_by_name 'To master'
      end

      exit(1) if is_error
    end
  end
end
