module Scenarios
  ##
  # CreateRelease scenario
  class CreateRelease
    def find_by_filter(issue, filter)
      issue.jql("filter=#{filter}")
    rescue JIRA::HTTPError => jira_error
      error_message = jira_error.response['body_exists'] ? jira_error.message : jira_error.response.body
      puts "Error in JIRA with the search by filter #{error_message}".red
      []
    end

    def find_by_tasks(issue, tasks)
      issues_from_string = []

      tasks.split(',').each do |issue_key|
        # Try to find issue by key
        begin
          issues_from_string << issue.find(issue_key)
        rescue JIRA::HTTPError => jira_error
          error_message = jira_error.response['body_exists'] ? jira_error.message : jira_error.response.body

          puts "Error in JIRA with the search by issue key #{error_message}".red
        end
      end

      issues_from_string
    end

    def create_release_issue(project, issue, project_key = 'OTT', release_name = 'Release')
      project = project.find(project_key)
      release = issue.build
      release.save(fields: { summary: release_name, project: { id: project.id },
                             issuetype: { name: 'Release' } })
      release.fetch
      release
    rescue JIRA::HTTPError => jira_error
      error_message = jira_error.response['body_exists'] ? jira_error.message : jira_error.response.body
      puts "Creation of release was failed with error #{error_message}".red
      raise error_message
    end

    # :nocov:
    def run
      params = SimpleConfig.release

      unless params
        puts 'No Release params in ENV'.red
        exit
      end

      if !params.filter && !params.tasks
        puts 'No necessary params - filter of tasks'.red
        exit
      end

      puts "Create release from filter #{params[:filter]} with name #{params[:name]}".green

      client = JIRA::Client.new SimpleConfig.jira.to_h

      issues = params.filter && find_by_filter(client.Issue, params.filter)

      if params.tasks && !params.tasks.empty?
        issues_from_string = find_by_tasks(client.Issue, params.tasks)
        issues = issues_from_string unless issues_from_string.empty?
      end

      begin
        release = create_release_issue(client.Project, client.Issue, params[:project], params[:name])
      rescue RuntimeError
        exit
      end

      puts "Start to link issues to release #{release.key}".green

      issues.each { |issue| issue.link(release.key) }

      puts "Create new release #{release.key} from filter #{params[:filter]}".green
    end
    # :nocov:
  end
end
