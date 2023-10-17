module Scenarios
  ##
  # ReviewIssue scenario
  class ReviewIssue
    def run
      LOGGER.info "Starting review #{SimpleConfig.jira.issue}"
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Запущена проверка тикета(!)
        #{ENV['BUILD_URL']} 
        Ожидайте сообщение о завершении
      {panel}
      BODY
      if Ott::Helpers.mobile_project?(issue.key)
        LOGGER.info 'Check mobile issue'
        # customfield_12166 - is Assemble field
        assemble_field = issue.fields['customfield_12166']
        if assemble_field.nil?
          message = 'Assemble field is empty. Please set up it'
          issue.post_comment <<-BODY
          {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
            #{message} (x)
          {panel}
          BODY
          LOGGER.error message
          issue.transition 'Conflicts'
          raise 'Assemble field is empty'
        end
        assemble = assemble_field['value']
        LOGGER.info "Assemble field is: #{assemble}"
        if assemble.include?('b2b_ott') && !issue.key.include?('IOS')
          LOGGER.warn 'Assemble=b2b_ott found. Need check if destination in PR is android_b2b project'
          # get all open PR
          LOGGER.info "Try to get all PR in status OPEN from #{issue.key}"
          pullrequests = issue.pullrequests(SimpleConfig.git.to_h)
                              .filter_by_status('OPEN')
                              .filter_by_source_url(SimpleConfig.jira.issue)

          if pullrequests.empty?
            issue.post_comment <<-BODY
                {panel:title=CodeOwners checker!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#b8b8e8|bgColor=#d2d2d2}
                В тикете нет открытых PR! Проверять нечего {noformat}¯\\_(ツ)_/¯{noformat}
                {panel}
            BODY
            exit 0
          end

          LOGGER.info "Found #{pullrequests.prs.size} PR in status OPEN"
          pullrequests.each do |pr|
            src_branch = pr.pr['source']['branch']
            pr_dst_url = pr.pr['destination']['url']
            # if pr_dst_url.include? 'android_b2b'
            #   LOGGER.info "Branch #{src_branch} has correct PR to android_b2b project"
            #   next
            # else
            #   msg = "Branch #{src_branch} has incorrect PR destination project. Should be android_b2b, but now another"
            #   issue.post_comment <<-BODY
            #     {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
            #       #{msg} (x)
            #     {panel}
            #   BODY
            #   LOGGER.error msg
            #   issue.transition 'Reopened'
            #   raise msg
            # end
          end
        else
          LOGGER.info "For assemble=#{assemble} no need any specific checks"
          exit 0
        end

      else
        LOGGER.info 'Check web issue'
        # Check PR names
        Ott::CheckPullRequests.run(issue)
        # Check builds status
        Ott::CheckBuildStatuses.for_open_pull_request(issue)
      end
    end
  end
end
