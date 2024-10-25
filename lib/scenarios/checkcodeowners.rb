module Scenarios
  ##
  # Add code owners to PR
  class CheckCodeOwners
    DEFAULT_REVIEWERS_COUNT = 2

    def run
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      # noinspection RubyArgCount
      abort('Only IOS project supports this feature') if SimpleConfig.jira.issue.include?('ADR')
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info "Try to get all PR in status OPEN from #{issue.key}"
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
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
        pr_repo = git_repo(pr.pr['destination']['url'])
        pr_name = pr.pr['name']
        pr_id = pr.pr['id']
        branch_name = pr.pr['source']['branch']['name']
        LOGGER.info "Branch Name: #{branch_name}" 
        reviewers = []
        pr_author = []
        diff_stats = {}
        owners_config = {}
        pr_description = ''
        with pr_repo do
          pr_info = get_pr_full_info(pr_id)
          pr_description = pr_info[:description]
          reviewers = pr_info[:reviewers]
          pr_author = pr_info[:author]
        end
        # Prepare account_id reviewers list from PR
        old_reviewers = get_reviewers_id(reviewers, pr_repo)
        # Get author id for case when he will be one of owners
        author_id = get_reviewers_id(pr_author, pr_repo).first
        # Get PR diff and owners_config
        with pr_repo do
          LOGGER.info 'Try to diff stats from BB'
          diff_stats = get_pullrequests_diffstats(pr_id)
          LOGGER.info 'Success!'
          LOGGER.info "Try to get owners.yml file for project #{remote.url.repo}"
          owners_config_path = "#{File.expand_path('../../../', __FILE__)}/#{remote.url.repo}/FileOwners.yaml" # rubocop:disable Style/ExpandPathArguments, Metrics/LineLength
          owners_config = YAML.load_file owners_config_path
          LOGGER.info "Success! Got file from #{owners_config_path}"
        end

        modified_files = get_modified_links(diff_stats)
        # Get codeOwners
        new_reviewers = get_owners(owners_config, modified_files, author_id, branch_name)

        if old_reviewers.empty?
          if new_reviewers.empty?
            LOGGER.warn 'Need to add random code reviewers in PR'
            new_reviewers_id = random_reviewers_from_config(owners_config, author_id, DEFAULT_REVIEWERS_COUNT)
            new_reviewers_list = prepare_reviewers_list(new_reviewers_id, author_id)
            message = 'Add random reviewers'
          else
            # Prepare new_reviewers_list
            new_reviewers_list = prepare_new_reviewers_list(old_reviewers, new_reviewers, author_id)
            new_reviewers_list = new_reviewers_list.uniq # for case when owner already add in reviewer, but not enough reviewers
            message = "Add code owners next projects #{new_reviewers.keys} in reviewers"
            if new_reviewers_list.empty?
              LOGGER.warn('PR change files where code owner == PR author. I will add two random users in review')
              new_reviewers_id = random_reviewers_from_config(owners_config, author_id, DEFAULT_REVIEWERS_COUNT)
              new_reviewers_list = prepare_reviewers_list(new_reviewers_id, author_id)
              message = 'Found case when Code owner and PR author the same person. I will add two random users in review'
            elsif new_reviewers_list.count < DEFAULT_REVIEWERS_COUNT
              LOGGER.warn('New reviewer list has less than 2 people. Need add one more random reviewer')
              new_reviewers_id_list = get_new_reviewers_id_list(new_reviewers_list)
              new_reviewers_id = random_reviewers_from_config(owners_config, [author_id, old_reviewers, new_reviewers_id_list].flatten,
                                                              (DEFAULT_REVIEWERS_COUNT - new_reviewers_list.size))
              new_reviewers_list += prepare_reviewers_list(new_reviewers_id, author_id)
              message = 'Not enough owners for review(should be at least 2). I will add random reviewer '
            elsif new_reviewers_list.count > DEFAULT_REVIEWERS_COUNT
              LOGGER.warn('More than 2 reviewers. Selecting randomly 2 reviewers.')
              new_reviewers_list = new_reviewers_list.sample(DEFAULT_REVIEWERS_COUNT)
            end
          end
        end

        # Prepare full description
        description = prepare_pr_description(pr_description, message)

        # Add info and new reviewers in PR
        with pr_repo do
          LOGGER.info 'Try to add reviewers to PR'
          add_info_in_pullrequest(pr_id, description, new_reviewers_list, pr_name)
          LOGGER.info 'Success! Everything fine!'
        end
      end

      issue.post_comment <<-BODY
      {panel:title=CodeOwners checker!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#b8b8e8|bgColor=#d2d2d2}
        Проверка codeowners завершена!(/)
      {panel}
      BODY
    end

    def prepare_pr_description(description, message)
      if description.empty?
        "**System:** #{message}"
      elsif description.include?('**System:**')
        description
      else
        "#{description} \n\n **System:** #{message}"
      end
    end

    def with(instance, &block)
      instance.instance_eval(&block)
      instance
    end

    def get_modified_links(diff_stats)
      LOGGER.info 'Try to get modified files'
      result = []
      statuses = %w[modified removed]
      diff_stats[:values].each do |diff|
        result << diff[:old][:path] if statuses.include? diff[:status]
      end
      LOGGER.info 'Success!'
      result
    end

    def get_reviewers_id(reviewers, pr_repo)
      LOGGER.info 'Try to get current reviewers id'
      result = []
      reviewers = [reviewers] unless reviewers.is_a? Array
      with pr_repo do
        reviewers.each do |user|
          # Name with space should replace with +
          result << user[:account_id]
        end
      end
      LOGGER.info "Success! Result: #{result}"
      result
    end

    def get_owners(owners_config, diff, author_id, branch_name)
      LOGGER.info 'Try to get owners ids'
      result = {}
      diff.each do |item|
        owners_config.each do |product|
          next if product[0] == 'reviewers'
          if product[1]['files'].include? item
            owners = product[1]['owners'].reject { |owner| owner == author_id }
            
            qa_owners = if branch_name.start_with?('uitests')
              product[1].key?('qa') ? product[1]['qa'].reject { |qa_owner| qa_owner == author_id } : []
            else
              []
            end
            
            selected_owners = []
            selected_owners << qa_owners.sample unless qa_owners.empty?
            selected_owners << owners.sample unless owners.empty?
            result[product[0]] = selected_owners unless selected_owners.empty?
          end
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

    def random_reviewers_from_config(config, remove_id, count)
      if remove_id.is_a?(Array)
        remove_id.reject(&:empty?).each do |id|
          config['reviewers'].delete(id)
        end
      else
        # Delete PR author from reviewers list
        config['reviewers'].delete(remove_id)
      end
      # Get random users from list
      config['reviewers'].sample(count)
    end

    def get_new_reviewers_id_list(reviewers_list)
      LOGGER.info 'Create new reviewer id list'
      result = []
      reviewers_list.each { |reviewer| result << reviewer[:account_id] }
      LOGGER.info "Success! new reviewer id list: #{result}"
      result
    end
  end
end
