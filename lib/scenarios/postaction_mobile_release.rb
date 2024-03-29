require 'slack-notifier'

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
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Запущено подмерживание релизных веток и закрытие тикетов(!)
        #{ENV['BUILD_URL']}
        Ожидайте сообщение о завершении
      {panel}
      BODY
      is_error = false
      is_master_updated = false
      is_b2b_project = false
      is_b2c_project = false
      # customfield_12166 - is Assemble field
      case project_name(issue.fields['customfield_12166']['value'])
        when 'android_ott'
          is_b2c_project = true
        when 'android_b2b'
          is_b2b_project = true
      end

      LOGGER.info "Try to get all PR in status OPEN from #{issue.key}"
      pullrequests = issue.pullrequests(SimpleConfig.git.to_h)
                          .filter_by_status('OPEN')
                          .filter_by_source_url(SimpleConfig.jira.issue)

      LOGGER.info "Found #{pullrequests.prs.size} PR in status OPEN"

      @fix_version = issue.fields['fixVersions']

      release_label = issue.fields['labels'].first

      # If this are IOS or ANDROID project we need to add tag on merge commit
      tag_enable = issue.key.include?('IOS') || issue.key.include?('ADR')
      # Work with release branch
      pullrequests.each do |pr| # rubocop:disable Metrics/BlockLength
        is_master_updated = false
        LOGGER.info 'Try to find release branch'
        next unless pr.pr['name'].include?('release')

        begin
          LOGGER.info "Found release PR: #{pr.pr['source']['branch']}"
          local_repo = pr.repo

          # Add tag on merge commit
          if tag_enable
            tag = "#{@fix_version.first['name']}-#{release_label}"
            LOGGER.info "Try to add tag #{tag} to #{pr.pr['destination']['branch']}"
            local_repo.add_tag(tag, pr.pr['destination']['branch'], messsage: 'Add tag to merge commit', f: true)
            local_repo.push('origin', "refs/tags/#{tag}", f: true)
            LOGGER.info 'Success!'
          end
          LOGGER.info "Try to merge #{pr.src.branch} in #{pr.dst}/#{pr.dst.branch}"
          local_repo.push('origin', pr.pr['destination']['branch'])
          LOGGER.info 'Success!'
          is_master_updated = true

          # IF repo is `ios-12trip` so make PR from updated master to develop
          if pr.pr['destination']['url'].include?('ios-12trip')
            LOGGER.warn 'Try to make PR from master to develop'
            with local_repo do
              checkout('master')
              pull
              create_pullrequest(
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

      if is_error
        LOGGER.error "Some PR didn't merge"
        issue.transition 'Undo code merge'
        exit(1)
      else
        LOGGER.info "Everything fine. Try to move tickets to 'DONE' status"
        # Work with tickets
        issue.linked_issues('deployes').each do |subissue|
          # Transition to DONE
          subissue.transition 'To master' if subissue.get_transition_by_name 'To master'
        end
      end
      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Мерж релизных веток - завершен. Перевод задач - завершен (/)
      {panel}
      BODY

      # Sync Android b2c/b2b repos
      if Ott::Helpers.mobile_project?(issue.key) && is_master_updated && !issue.key.include?('IOS')
        webhook_url = ENV['SLACK_WEB_HOOK']
        if is_b2c_project
          LOGGER.info 'B2C project was updated'
          LOGGER.info 'Make PR из B2c master -> B2B develop (report slack channel)'
          res = Git::Base.new.create_pullrequest_throw_api(
            repo_full_name: 'OneTwoTrip/android_b2b',
            title: 'B2C Master to B2B develop',
            description: 'AUTO: B2C Master to B2B develop',
            src_branch_name: 'master',
            src_repo_full_name: 'OneTwoTrip/android_ott',
            dst_branch_name: 'develop',
            reviewers: default_android_reviewers
          )
          notifier = Slack::Notifier.new webhook_url
          notifier.ping "<!subteam^SU96ZR6DQ> Был сформирован pr из android_ott в android_b2b: https://bitbucket.org/OneTwoTrip/android_b2b/pull-requests/#{JSON.parse(res)['id']} :ottb2b:"
        elsif is_b2b_project
          LOGGER.info 'B2B project was updated'
          LOGGER.info 'Make PR из B2B master -> B2C develop (report slack channel)'
          res = Git::Base.new.create_pullrequest_throw_api(
            repo_full_name: 'OneTwoTrip/android_ott',
            title: 'B2B Master to B2C develop',
            description: 'AUTO: B2B Master to B2C develop',
            src_branch_name: 'master',
            src_repo_full_name: 'OneTwoTrip/android_b2b',
            dst_branch_name: 'develop',
            reviewers: default_android_reviewers
          ) # JSON.parse(res)["id"]
          notifier = Slack::Notifier.new webhook_url
          notifier.ping "<!subteam^SU96ZR6DQ> Был сформирован pr из android_b2b в android_ott: https://bitbucket.org/OneTwoTrip/android_ott/pull-requests/#{JSON.parse(res)['id']} :ott:"
        else
          LOGGER.warn 'B2C/B2B develop update skipped'
        end
      end
    end

    # Return which repo was updated
    # @param assemble_value - Value from Jira release ticket
    def project_name(assemble_value)
      case assemble_value
        when 'b2b_ott'
          'android_b2b'
        when 'b2c_ott'
          'android_ott'
      end
    end

    def default_android_reviewers
      [
        {
          uuid: '{c5aa798c-62b9-4644-af9a-e540b2cce219}', # vitaliy.ermakov
        },
      ]
    end
  end
end
