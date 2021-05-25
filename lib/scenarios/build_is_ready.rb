module Scenarios
  # Check build.tiket.com contains SUCCESS status for build
  class BuildIsReady

    def run
      LOGGER.info "Starting check build status for #{SimpleConfig.jira.issue}"
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Проверяем статус билда(!)
        #{ENV['BUILD_URL']} 
        Ожидайте сообщение о завершении
      {panel}
      BODY

      Ott::CheckBuildStatuses.for_mobile_open_pull_request(issue)
    end
  end
end

