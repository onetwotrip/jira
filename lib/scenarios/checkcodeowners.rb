module Scenarios
  ##
  # Add code owners to PR
  class CheckCodeOwners
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
      pullrequests.each do |pr| # rubocop:disable Metrics/BlockLength
        LOGGER.info "Start work with PR: #{pr.pr['url']}"
        pr_repo   = git_repo(pr.pr['destination']['url'])
        pr_name   = pr.pr['name']
        pr_id     = pr.pr['id']
        reviewers = pr.pr['reviewers']
        pr_author = pr.pr['author']
        # Prepare account_id reviewers list from PR
        old_reviewers = get_reviewers_id(reviewers, pr_repo)
        # Get author id for case when he will be one of owners
        author_id     = get_reviewers_id(pr_author, pr_repo).first
        diff_stats    = {}
        owners_config = {}
        # Get PR diff and owners_config
        with pr_repo do
          LOGGER.info 'Try to diff stats from BB'
          diff_stats = get_pullrequests_diffstats(pr_id)
          LOGGER.info 'Success!'
          LOGGER.info "Try to get owners.yml file for project #{remote.url.repo}"
          owners_config_path = "#{File.expand_path('../../../', __FILE__)}/bin/#{remote.url.repo}/FileOwners.yaml" # rubocop:disable Style/ExpandPathArguments, Metrics/LineLength
          owners_config      = YAML.load_file owners_config_path
          LOGGER.info "Success!Got file from #{owners_config_path}"
        end

        modified_files = get_modified_links(diff_stats)
        # Get codeOwners
        new_reviewers = get_owners(owners_config, modified_files)

        if new_reviewers.empty?
          LOGGER.warn 'No need to add code owners in reviewers'
          if old_reviewers.empty?
            LOGGER.info 'Need to add random code reviewers in PR'
            new_reviewers_id   = random_reviewers_from_config(owners_config, author_id, 2)
            new_reviewers_list = prepare_reviewers_list(new_reviewers_id, author_id)
          else
            LOGGER.info 'PR contains reviewers. Everything fine!'
            exit(0)
          end
        else
          # Prepare new_reviewers_list
          new_reviewers_list = prepare_new_reviewers_list(old_reviewers, new_reviewers, author_id)
          if new_reviewers_list.empty?
            LOGGER.warn('PR change files where code owner == PR author. I will add two random users in review')
            new_reviewers_id   = random_reviewers_from_config(owners_config, author_id, 2)
            new_reviewers_list = prepare_reviewers_list(new_reviewers_id, author_id)
          end
        end
        message = case new_reviewers.empty?
                  when true
                    'Add random reviewers'
                  when false
                    "Add code owners next projects #{new_reviewers.keys} in reviewers"
                  end
        # Add info and new reviewers in PR
        with pr_repo do
          LOGGER.info 'Try to add reviewers to PR'
          add_info_in_pullrequest(pr_id, message, new_reviewers_list, pr_name)
          LOGGER.info 'Success! Everything fine!'
        end
      end

      issue.post_comment <<-BODY
      {panel:title=CodeOwners checker!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#b8b8e8|bgColor=#d2d2d2}
        Проверка codeowners завершена!(/)
      {panel}
      BODY
    end

    def with(instance, &block)
      instance.instance_eval(&block)
      instance
    end

    def get_modified_links(diff_stats)
      LOGGER.info 'Try to get modified files'
      result   = []
      statuses = %w[modified removed]
      diff_stats[:values].each do |diff|
        result << diff[:old][:path] if statuses.include? diff[:status]
      end
      LOGGER.info 'Success!'
      result
    end

    def get_reviewers_id(reviewers, pr_repo)
      LOGGER.info 'Try to get current reviewers id'
      result    = []
      reviewers = [reviewers] unless reviewers.is_a? Array
      with pr_repo do
        reviewers.each do |user|
          # Name with space should replace with +
          result << get_reviewer_info(user['name'].sub(' ', '+')).first[:mention_id]
        end
      end
      LOGGER.info "Success! Result: #{result}"
      result
    end

    def get_owners(owners_config, diff)
      LOGGER.info 'Try to get owners ids'
      result = {}
      diff.each do |item|
        owners_config.each do |product|
          next if product[0] == 'reviewers'
          result[product[0]] = product[1]['owners'] if product[1]['files'].include? item
        end
      end
      LOGGER.info "Success! Result: #{result}"
      result
    end

    def prepare_reviewers_list(reviewers_list, author_id)
      LOGGER.info 'Try to prepare reviewers list for add to PR'
      result = []
      reviewers_list.each do |id|
        result << { account_id: id } unless id == author_id
      end
      LOGGER.info "Success! Result: #{result}"
      result
    end

    def prepare_new_reviewers_list(old_reviewers, owners, author_id)
      LOGGER.info 'Try to prepare reviewers list for add to PR'
      result = []
      old_reviewers.each { |reviewer| result << { account_id: reviewer } }
      owners.each do |owner|
        owner[1].each do |id|
          result << { account_id: id } unless id == author_id
        end
      end
      LOGGER.info "Success! Result: #{result}"
      result
    end

    def random_reviewers_from_config(config, author_id, count)
      # Delete PR author from reviewers list
      config['reviewers'].delete(author_id)
      # Get random users from list
      config['reviewers'].sample(count)
    end
  end
end
