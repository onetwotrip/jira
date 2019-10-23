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
        pr_repo           = pr.repo
        pr_name           = pr.pr['name']
        pr_id             = pr.pr['id']
        reviewers         = pr.pr['reviewers']
        reviewers_id_list = get_reviewers_id(reviewers, pr_repo)
        diff_stats        = {}
        with pr_repo do
          diff_stats = get_pullrequests_diffstats(pr_id)
          add_info_in_pullrequest(pr_id, 'Description without reviewers ok', nil, pr_name)
        end
        modified_files = get_modified_links(diff_stats)
        modified_files
      end
    end

    def get_modified_links(diff_stats)
      result   = []
      statuses = %w[modified removed]
      diff_stats[:values].each do |diff|
        result << diff[:old][:path] if statuses.include? diff[:status]
      end
      result
    end

    def get_reviewers_id(reviewers, pr_repo)
      result = []
      with pr_repo do
        reviewers.each do |user|
          result << get_reviewer_info(user['name']).first[:mention_id]
        end
      end
      result
    end
  end
end
