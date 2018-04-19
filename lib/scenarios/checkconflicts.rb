module Scenarios
  ##
  # CheckConflicts scenario
  class CheckConflicts
    def find_by_filter(issue, filter)
      issue.jql("filter=#{filter}")
    rescue JIRA::HTTPError => jira_error
      error_message = jira_error.response['body_exists'] ? jira_error.response.body : jira_error.message
      puts "Error in JIRA with the search by filter #{error_message}".red
      []
    end

    def check_issue(issue_task)
      issue_task.api_pullrequests.each do |pr|
        diff_in_pr = pr.diff
        commit_id = pr.source['commit']['hash']
        commit = BITBUCKET.repo(pr.repo_owner, pr.repo_slug).commit(commit_id)
        status_of_build = commit.build_statuses.collect.last
        conflict_flag = diff_in_pr.include? '<<<<<<<'
        log_string = "Status of pullrequest #{pr.title} is #{status_of_build.name}:#{status_of_build.state} and ".green
        conflict_flag_log = "conflict_flag is #{conflict_flag}".green
        conflict_flag_log = "conflict_flag is #{conflict_flag}".red if conflict_flag

        log_string += conflict_flag_log + " with link https://bitbucket.org/OneTwoTrip/#{pr.repo_slug}/".green +
                      "pull-requests/#{pr.id}".green
        puts log_string
      end
    end

    # :nocov:
    def run
      filter = SimpleConfig.filter

      unless filter
        puts 'No necessary params - filter'.red
        exit
      end

      puts "Check conflicts in tasks from filter #{filter}".green
      client = JIRA::Client.new SimpleConfig.jira.to_h
      issues = filter && find_by_filter(client.Issue, filter)
      puts 'Start check issues'.green
      issues.each { |issue| check_issue(issue) }
    end
    # :nocov:
  end
end
