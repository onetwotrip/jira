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
        pr_repo   = pr.repo
        pr_name   = pr.pr['name']
        pr_id     = pr.pr['id']
        reviewers = pr.pr['reviewers']
        pr_author = pr.pr['author']
        # Prepare account_id reviewers list from PR
        old_reviewers = get_reviewers_id(reviewers, pr_repo)
        # Get author id for case when he will be one of owners
        author_id = get_reviewers_id(pr_author, pr_repo)[:account_id]
        diff_stats    = {}
        owners_config = {}
        # Get PR diff
        with pr_repo do
          diff_stats         = get_pullrequests_diffstats(pr_id)
          owners_config_path = File.expand_path('../../../', __FILE__)
          owners_config      = YAML.load_file "#{owners_config_path}/bin/#{remote.url.repo}/owners.yml"
        end

        modified_files = get_modified_links(diff_stats)
        # Get codeOwners
        new_reviewers = get_owners(owners_config, modified_files, author_id)
        # Prepare new_reviewers_list
        new_reviewers_list = prepare_new_reviewers_list(old_reviewers, new_reviewers)

        # Add info and new reviewers in PR
        with pr_repo do
          add_info_in_pullrequest(pr_id, 'Description without reviewers ok', new_reviewers_list, pr_name)
        end
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
      reviewers = [reviewers] unless reviewers.is_a? Array
      with pr_repo do
        reviewers.each do |user|
          # Name with space should replace with +
          result << { account_id: get_reviewer_info(user['name'].sub(' ', '+')).first[:mention_id] }
        end
      end
      result
    end

    def get_owners(owners_config, diff, author_id)
      result = {}
      diff.each do |item|
        owners_config.each do |product|
          if product[1]['files'].include? item
            result[product[0]] = product[1]['owners']
          end
        end
      end
      result
    end

    def prepare_new_reviewers_list(old_reviewers, owners)
      result = old_reviewers
      owners.each do |owner|
        result << { account_id: owner[1].first }
      end
      result
    end
  end
end
