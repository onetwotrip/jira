module Scenarios
  ##
  # Add code owners to PR
  class CheckCodeOwners
    def run
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      # noinspection RubyArgCount
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      diff = issue.api_pullrequests
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
      end

      LOGGER.info "Found #{pullrequests.prs.size} PR in status OPEN"

      pullrequests.each do |pr|
        puts pr.pr['id']
      end
    end
  end
end
