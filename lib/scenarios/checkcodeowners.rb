module Scenarios
  ##
  # Add code owners to PR
  class CheckCodeOwners

    def with(instance, &block)
      instance.instance_eval(&block)
      instance
    end

    def run
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      # noinspection RubyArgCount
      abort('Only IOS project supports this feature') if SimpleConfig.jira.issue.include?('ADR')
      issue = jira.Issue.find(SimpleConfig.jira.issue)
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
        LOGGER.info "Start work with PR: #{pr.pr['url']}"
        pr_repo     = pr.repo
        diff_stats = {}
        with pr_repo do
          diff_stats = get_pullrequests_diffstats(pr.pr['id'])
        end
        diff_stats
      end
    end
  end
end
