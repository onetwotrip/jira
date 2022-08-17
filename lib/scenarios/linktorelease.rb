module Scenarios
  ##
  # Link tickets to release issue
  class LinkToRelease
    def find_by_filter(issue, filter)
      issue.jql("filter=#{filter}", max_results: 100)
    rescue JIRA::HTTPError => jira_error
      error_message = jira_error.response['body_exists'] ? jira_error.message : jira_error.response.body
      LOGGER.error "Error in JIRA with the search by filter #{filter}: #{error_message}"
      []
    end

    def run
      params = SimpleConfig.release

      unless params
        LOGGER.error 'No Release params in ENV'
        exit
      end

      filter_config = JSON.parse(ENV['RELEASE_FILTER'])
      client = JIRA::Client.new SimpleConfig.jira.to_h
      issue = client.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s

      project_name = issue.fields['project']['key']
      release_name = issue.fields['summary'].upcase
      release_issue_number = issue.key
      # customfield_12166 - is Assemble field
      assemble_field = issue.fields['customfield_12166']
      if assemble_field.nil? && mobile_project?(issue.key)
        message = 'Assemble field is empty. Please set up it'
        issue.post_comment <<-BODY
          {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
            #{message} (x)
          {panel}
        BODY
        LOGGER.error message
        raise 'Assemble field is empty'
      elsif mobile_project?(issue.key)
        assemble = assemble_field['value'] || ''
      end

      # Check project exist in filter_config
      if filter_config[project_name].nil?
        message = "I can't work with project '#{project_name.upcase}'. Pls, contact administrator to feedback"
        issue.post_comment <<-BODY
          {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
            #{message} (x)
          {panel}
        BODY
        LOGGER.error message
        raise 'Project not found'
      end

      LOGGER.info "Linking tickets to release '#{release_name}'"

      # Check release type
      release_type = if %w[_BE_ _BE BE_ BE].any? { |str| release_name.include?(str) }
                       'backend'
                     elsif %w[_FE_ _FE FE_ FE].any? { |str| release_name.include?(str) }
                       'frontend'
                     else
                       'common'
                     end

      LOGGER.info "Release type: #{release_type}"
      release_filter = filter_config[project_name][release_type]

      if mobile_project?(issue.key)
        release_filter = if assemble.empty?
                           "#{release_filter} AND (assemble = b2c_ott OR assemble is EMPTY)"
                         else
                           "#{release_filter} AND assemble = #{assemble}"
                         end
      else
        release_filter
      end

      # Check release filter
      if release_filter.nil? || release_filter.empty?
        message = "I don't find release filter for jira project: '#{project_name.upcase}' and release_type: #{release_type}"
        issue.post_comment <<-BODY
          {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
            #{message} (x)
          {panel}
        BODY
        LOGGER.error message
        raise 'Release_filter not found'
      end

      LOGGER.info "Release filter: #{release_filter}"

      issues = release_filter && find_by_filter(client.Issue, release_filter)

      # Check issues not empty
      if issues.empty?
        LOGGER.warn "Release filter: #{release_filter} doesn't contain any issues"
        issue.post_comment <<-BODY
          {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
            Фильтр #{release_filter} не содержит задач (x)
          {panel}
        BODY
        exit
      else
        LOGGER.info "Release filter contains: #{issues.count} tasks"
      end

      # Message about count of release candidate issues
      issue.post_comment <<-BODY
          {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
            Тикетов будет прилинковано: #{issues.count} (!)
            #{ENV['BUILD_URL']}
          {panel}
      BODY

      issues.each do |i|
        i.link(release_issue_number)
      end

      unless %w[ADR IOS].any? { |p| release_issue_number.include? p }
        release_labels = []
        issues.each do |i|
          i.related['branches'].each do |branch|
            release_labels << branch['repository']['name'].to_s
          end
        end

        release_labels.uniq!

        LOGGER.info "Add labels: #{release_labels} to release #{release_name}"
        issue.save(fields: { labels: release_labels })
        issue.fetch
      end

      # Message about done
      issue.post_comment <<-BODY
          {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
            Формирование релиза закончено (/)
          {panel}
      BODY
    end

    def mobile_project?(key)
      %w[ADR IOS].include? key.split('-').first
    end
  end
end
