module Scenarios
  ##
  # Check issue has merged special PR
  class MergeChecker
    def run
      taboo_repos = %w(back-components front-components)

      LOGGER.info "Starting check PR for #{taboo_repos} repos"
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
      issue.development.branches.each do |branch|
        LOGGER.info "Work with #{branch.repo}:#{branch.url}"
        next unless taboo_repos.include? branch.repo

        LOGGER.warn "Found repo from #{taboo_repos}. Check PR status"
        if %w[OPEN].include? branch.pr_status
          LOGGER.error 'Branch has open PR. Need to be merged before go next'
          issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  В задаче есть одна из веток #{taboo_repos}, которая должна быть замержена, прежде чем задача перейдет в Merge Ready статус.
                  Обратитесь к техлиду.
              {panel}
          BODY
          issue.transition 'Need Components Merge'
          exit 1
        else
          LOGGER.info "Branch: #{branch.url} has PR status: #{branch.pr_status}"
          issue.post_comment <<-BODY
              {panel:title=CodeOwners checker!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#b8b8e8|bgColor=#d2d2d2}
                  Все компоненты замержены(/)
              {panel}
          BODY
        end
      end
    end
  end
end
