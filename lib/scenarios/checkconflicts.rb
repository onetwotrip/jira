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
          diff_in_pr        = pr.diff
          commit_id         = pr.source['commit']['hash']
          commit            = BITBUCKET.repo(pr.repo_owner, pr.repo_slug).commit(commit_id)
          status_of_build   = commit.build_statuses.collect.last
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

          log_string += conflict_flag_log + " with link https://bitbucket.org/OneTwoTrip/#{pr.repo_slug}/".green +
            "pull-requests/#{pr.id}".green
          LOGGER.info log_string

        rescue StandardError => error
          LOGGER.info "There is error occured with ticket #{issue_task.key}: #{error.message}".red
        end
      end
    end

    # :nocov:
    def run
      filter = SimpleConfig.filter

      unless filter
        LOGGER.info 'No necessary params - filter'.red
        exit
      end

      LOGGER.info "Check conflicts in tasks from filter #{filter}".green
      client = JIRA::Client.new SimpleConfig.jira.to_h
      issues = filter && find_by_filter(client.Issue, filter)
      LOGGER.info 'Start check issues'.green
      issues.each { |issue| check_issue(issue) }
    end
    # :nocov:
  end
end


# kill Timeout module for debug bug in Rubymine
if $LOADED_FEATURES.any? { |f| f.include? 'debase' }
  module Timeout
    def timeout(sec, klass=nil)
      yield(sec)
    end

    module_function :timeout
  end
end