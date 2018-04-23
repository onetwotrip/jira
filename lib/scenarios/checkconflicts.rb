module Scenarios
  ##
  # CheckConflicts scenario
  class CheckConflicts
    def find_by_filter(issue, filter)
      issue.jql("filter=#{filter}")
    rescue JIRA::HTTPError => jira_error
      error_message = jira_error.response['body_exists'] ? jira_error.message : jira_error.response.body
      LOGGER.info "Error in JIRA with the search by filter #{error_message}".red
      []
    end

    def check_issue(issue_task)
      LOGGER.info "Start check #{issue_task.key} issue".green
      issue_task.api_pullrequests.each do |pr|
        begin
          diff_in_pr      = pr.diff
          commit_id       = pr.source['commit']['hash']
          commit          = BITBUCKET.repo(pr.repo_owner, pr.repo_slug).commit(commit_id)
          status_of_build = commit.build_statuses.collect.last
          if status_of_build.state.upcase.include? 'FAILED'
            LOGGER.info "Detected build status error in #{issue_task.key}. Writing comment in ticket...".red
            issue_task.post_comment 'Ticket has build error status, pls check it'
          end
          conflict_flag     = diff_in_pr.include? '<<<<<<<'
          log_string        = "Status of pullrequest #{pr.title} is #{status_of_build.name}:#{status_of_build.state} and ".green
          conflict_flag_log = "conflict_flag is #{conflict_flag}".green
          if conflict_flag
            LOGGER.info "Find conflicts in #{issue_task.key}. Writing comment in ticket..."
            conflict_flag_log = "conflict_flag is #{conflict_flag}".red
            issue_task.post_comment 'After last release this issue started to have merge conflicts. Please fix it'
            LOGGER.info "Finished writing merge conflict message in #{issue_task.key}"
          end

          log_string += conflict_flag_log + " with link https://bitbucket.org/OneTwoTrip/#{pr.repo_slug}/pull-requests/#{pr.id}".green
          LOGGER.info log_string
        rescue StandardError => error
          LOGGER.info "There is error occured with ticket #{issue_task.key}: #{error.message}".red
        end
      end
    end

    # :nocov:
    def run
      LOGGER.info 'Start check conflicts'.green
      client        = JIRA::Client.new SimpleConfig.jira.to_h
      release_issue = client.Issue.find(SimpleConfig.jira.issue)
      project_name  = release_issue.fields['project']['key']
      release_name  = release_issue.fields['summary'].upcase

      LOGGER.info "Found release ticket: #{release_issue.key} in project: #{project_name}"
      filter_config = JSON.parse(ENV['RELEASE_FILTER'])
      # Check project exist in filter_config
      if filter_config[project_name].nil?
        message = "I can't work with project '#{project_name.upcase}'. Pls, contact administrator to feedback"
        LOGGER.error message
        raise "Project: '#{project_name}' not found".red
      end

      # Check release type
      release_type = if %w[_BE_ _BE BE_ BE].any? { |str| release_name.include?(str) }
                       'backend'
                     elsif %w[_FE_ _FE FE_ FE].any? { |str| release_name.include?(str) }
                       'frontend'
                     else
                       'common'
                     end

      LOGGER.info "Release type: #{release_type}".green
      release_filter = filter_config[project_name][release_type]
      # Check release filter
      if release_filter.nil? || release_filter.empty?
        message = "I don't find release filter for jira project: '#{project_name.upcase}' and release_type: #{release_type}"
        release_issue.post_comment(message)
        LOGGER.error message
        raise 'Release_filter not found'
      end

      LOGGER.info "Found release filter: #{release_filter} for project: #{project_name}"
      unless release_filter
        LOGGER.info 'No necessary params - filter'.red
        exit
      end

      LOGGER.info "Check conflicts in tasks from filter #{release_filter}".green
      issues = release_filter && find_by_filter(client.Issue, release_filter)
      LOGGER.info 'Start check issues'.green
      issues.each { |issue| check_issue(issue) }
    end
    # :nocov:
  end
end
