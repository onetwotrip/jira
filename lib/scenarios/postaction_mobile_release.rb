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

      pullrequests = issue.pullrequests(SimpleConfig.git.to_h)
                          .filter_by_status('OPEN')
                          .filter_by_source_url(SimpleConfig.jira.issue)

      unless pullrequests.valid?
        issue.post_comment p("ReviewRelease: #{pullrequests.valid_msg}")
        exit
      end

      @fix_version = issue.fields['fixVersions']
      # If this are IOS or ANDROID project we need to add tag on merge commit
      tag_enable = issue.key.include?('IOS') || issue.key.include?('ADR')
      # Work with pullrequests
      pullrequests.each do |pr| # rubocop:disable Metrics/BlockLength
        # Checkout repo
        puts "Clone/Open with #{pr.dst} branch #{pr.dst.branch} and merge #{pr.src.branch} and push".green
        begin
          local_repo = pr.repo

          # Add tag on merge commit
          if tag_enable
            tag = @fix_version.first['name']
            local_repo.add_tag(tag, pr.pr['destination']['branch'], messsage: 'Add tag to merge commit', f: true)
            local_repo.push('origin', "refs/tags/#{tag}", f: true)
          end

          # Decline PR if destination branch is develop
          if pr.pr['name'].include?('feature')
            puts 'Try to decline PR to develop'.yellow
            with local_repo do
              LOGGER.info "Decline PR: #{pr.pr['source']['branch']}"
              if pr.pr['status'].include?('OPEN')
                LOGGER.info "Found PR: #{pr.pr['source']['branch']} with status OPEN. Try to decline"
                decline_pullrequest(
                  SimpleConfig.bitbucket[:username],
                  SimpleConfig.bitbucket[:password],
                  pr.pr['id']
                )
              end
            end
            puts 'Decline PR to develop success'.green
            next
          end
          local_repo.push('origin', pr.pr['destination']['branch'])

          # IF repo is `ios-12trip` so make PR from updated master to develop
          if pr.pr['destination']['url'].include?('ios-12trip')
            puts 'Try to make PR from master to develop'.yellow
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
            puts 'Make success PR!'.green
          end
        rescue Git::GitExecuteError => e
          is_error = true
          puts e.message.red
          if e.message.include?('Merge conflict')
            issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  Не удалось замержить PR: #{pr.pr['url']}
                  *Причина:* Merge conflict
              {panel}
            BODY
          else
            issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  Не удалось замержить PR: #{pr.pr['url']}
                  *Причина:* #{e.message}
              {panel}
            BODY
          end
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
