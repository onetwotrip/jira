module Scenarios
  ##
  # CreateRelease scenario
  class CreateRelease
    def find_by_filter(issue, filter)
      issue.jql("filter=#{filter}")
    rescue JIRA::HTTPError => jira_error
      error_message = jira_error.response['body_exists'] ? jira_error.message : jira_error.response.body
      LOGGER.error "Error in JIRA with the search by filter #{error_message}"
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

          LOGGER.error "Error in JIRA with the search by issue key #{error_message}"
        end
      end

      issues_from_string
    end

    def create_release_issue(project, issue, project_key = 'OTT', release_name = 'Release', release_labels = [])
      project = project.find(project_key)
      release = issue.build
      release.save(fields: { summary: release_name, project: { id: project.id },
                             issuetype: { name: 'Release' }, labels: release_labels })
      release.fetch
      release
    rescue JIRA::HTTPError => jira_error
      error_message = jira_error.response['body_exists'] ? jira_error.message : jira_error.response.body
      LOGGER.error "Creation of release was failed with error #{error_message}"
      raise error_message
    end

    # :nocov:
    def run
      params = SimpleConfig.release

      unless params
        LOGGER.error 'No Release params in ENV'
        exit
      end

      if !params.filter && !params.tasks
        LOGGER.error 'No necessary params - filter of tasks'
        exit
      end

      LOGGER.info "Create release from filter #{params[:filter]} with name #{params[:name]}"

      client = JIRA::Client.new SimpleConfig.jira.to_h

      issues = params.filter && find_by_filter(client.Issue, params.filter)

      if params.tasks && !params.tasks.empty?
        issues_from_string = find_by_tasks(client.Issue, params.tasks)
        issues = issues_from_string unless issues_from_string.empty?
      end

      release_labels = params.labels if params.labels

      begin
        release = create_release_issue(client.Project, client.Issue, params[:project], params[:name], release_labels)
      rescue RuntimeError
        exit
      end

      LOGGER.info "Start to link issues to release #{release.key}"

      issues.each { |issue| issue.link(release.key) }

      LOGGER.info "Created new release #{release.key} from filter #{params[:filter]}"

      # Get repo's name from Jira Ticket
      issue = client.Issue.find(release.key)

      issue.related['branches'].each do |branch|
        puts branch['repository']['name']
      end


      LOGGER.info "Storing '#{release.key}' to file, to refresh buildname in Jenkins"
      Ott::Helpers.export_to_file(release.key, 'release_name.txt')
    end
    # :nocov:
  end
end
