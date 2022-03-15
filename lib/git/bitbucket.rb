require 'rest-client'
require 'json'

##
# This module extends Git
module Git
  ##
  # Add methods for Git::Base
  class Base
    # :nocov:
    def create_pullrequest(src = current_branch, destination = 'master')
      request = { title: "#{src} #{remote.url.repo}",
                  source: { branch: { name: src },
                            repository: { full_name: remote.url.repo } },
                  destination: { branch: { name: destination } } }
      begin
        url = "https://api.bitbucket.org/2.0/repositories/#{remote.url.repo}/pullrequests"
        LOGGER.info "POST #{url}"
        RestClient::Request.execute(
          method: :post,
          url: url,
          user: SimpleConfig.bitbucket[:username],
          password: SimpleConfig.bitbucket[:password],
          payload: request.to_json,
          headers: { content_type: :json }
        )
      rescue StandardError => e
        LOGGER.fatal "Pullrequest didn't create"
        LOGGER.fatal "Error: #{e}; URL: #{url}; PARAMS: #{request}"
        if e.response.include? 'There are no changes to be pulled'
          LOGGER.warn e.response
        else
          exit 1
        end
      end
    end

    def create_pullrequest_throw_api(repo_full_name: nil, title: nil, description: nil, src_branch_name: nil,
                                     src_repo_full_name: nil, dst_branch_name: nil, reviewers: nil)
      request = {
        title: title,
        description: description,
        source: {
          branch: {
            name: src_branch_name,
          },
          repository: {
            full_name: src_repo_full_name,
          },
        },
        destination: {
          branch: {
            name: dst_branch_name,
          },
        },
        reviewers: reviewers,
        close_source_branch: false,
      }
      begin
        url = "https://api.bitbucket.org/2.0/repositories/#{repo_full_name}/pullrequests"
        LOGGER.info "POST #{url}"
        RestClient::Request.execute(
          method: :post,
          url: url,
          user: SimpleConfig.bitbucket[:username],
          password: SimpleConfig.bitbucket[:password],
          payload: request.to_json,
          headers: { content_type: :json }
        )
      rescue StandardError => e
        LOGGER.fatal "Pullrequest didn't create"
        LOGGER.fatal "Error: #{e}; URL: #{url}; PARAMS: #{request}"
        if e.response.include? 'There are no changes to be pulled'
          LOGGER.warn e.response
        else
          exit 1
        end
      end
    end

    def merge_pullrequest(pull_request_id = '')
      url = "https://api.bitbucket.org/2.0/repositories/#{remote.url.repo}/pullrequests/#{pull_request_id}/merge" # rubocop:disable Metrics/LineLength
      request = {
        merge_strategy: 'merge_commit',
        close_source_branch: true,
      }.compact
      RestClient::Request.execute(
        method: :post,
        url: url,
        payload: request.to_json,
        headers: { content_type: :json },
        user: SimpleConfig.bitbucket[:username],
        password: SimpleConfig.bitbucket[:password]
      )
    rescue StandardError => e
      LOGGER.fatal "Pullrequest didn't merge"
      LOGGER.fatal "Error: #{e}; URL: #{url}"
      LOGGER.fatal "Response: #{e.response}"
      raise e
    end

    # def decline_pullrequest(username = nil, password = nil, pull_request_id = '')
    #   url = "https://#{username}:#{password}@api.bitbucket.org/2.0/repositories/#{remote.url.repo}/pullrequests/#{pull_request_id}/decline" # rubocop:disable Metrics/LineLength
    #   RestClient.post url, content_type: :json
    # rescue StandardError => e
    #   LOGGER.fatal "Pullrequest didn't decline"
    #   LOGGER.fatal "Error: #{e}; URL: #{url}"
    #   exit(1)
    # end

    def delete_branch(branch = current_branch)
      url = "https://api.bitbucket.org/2.0/repositories/#{branch.repo_owner}/#{branch.repo_slug}/refs/branches/#{branch.name}" # rubocop:disable Metrics/LineLength
      LOGGER.info "DELETE #{url}"
      RestClient::Request.execute(
        method: :delete,
        url: url,
        user: SimpleConfig.bitbucket[:username],
        password: SimpleConfig.bitbucket[:password]
      )
    rescue StandardError => e
      LOGGER.fatal "Got error when try to delete branch #{branch.name}: #{e.response}"
      exit(1)
    end

    # :nocov:
    def get_pullrequests_diffstats(id)
      url = "https://api.bitbucket.org/2.0/repositories/#{remote.url.repo}/pullrequests/#{id}/diffstat" # rubocop:disable Metrics/LineLength
      LOGGER.info "GET #{url}"
      response = RestClient::Request.execute(
        method: :get,
        url: url,
        user: SimpleConfig.bitbucket[:username],
        password: SimpleConfig.bitbucket[:password]
      )
      JSON.parse(response, symbolize_names: true)
    rescue StandardError => e
      LOGGER.fatal "Got error when try to get diff stats for PR:#{id} from #{remote.url.repo}"
      LOGGER.fatal "Error: #{e.response}"
      exit(1)
    end

    # :nocov:
    def get_reviewer_info(part_of_name)
      url = "https://bitbucket.org/xhr/mentions/repositories/#{remote.url.repo}?term=#{part_of_name}"
      LOGGER.info "GET #{url}"
      response = RestClient::Request.execute(
        method: :get,
        url: url,
        user: SimpleConfig.bitbucket[:username],
        password: SimpleConfig.bitbucket[:password]
      )
      JSON.parse(response, symbolize_names: true)
    rescue StandardError => e
      LOGGER.fatal "Got error when try to get reviewer info for name:#{part_of_name}"
      LOGGER.fatal "Error: #{e.response}"
      exit(1)
    end

    # :nocov:
    def get_pr_full_info(id)
      url = "https://api.bitbucket.org/2.0/repositories/#{remote.url.repo}/pullrequests/#{id}"
      LOGGER.info "GET #{url}"
      response = RestClient::Request.execute(
        method: :get,
        url: url,
        user: SimpleConfig.bitbucket[:username],
        password: SimpleConfig.bitbucket[:password]
      )
      JSON.parse(response, symbolize_names: true)
    rescue StandardError => e
      LOGGER.fatal "Got error when try to get full info about PR:#{id} from #{remote.url.repo}"
      LOGGER.fatal "Error: #{e.response}"
      exit(1)
    end

    # :nocov:
    def add_info_in_pullrequest(id, description = nil, reviewers = nil, title = nil)
      url = "https://api.bitbucket.org/2.0/repositories/#{remote.url.repo}/pullrequests/#{id}"
      request = {
        description: description,
        title: title,
        reviewers: reviewers,
        close_source_branch: true,
      }.compact

      LOGGER.info "PUT #{url}"
      response = RestClient::Request.execute(
        method: :put,
        url: url,
        payload: request.to_json,
        headers: { content_type: :json },
        user: SimpleConfig.bitbucket[:username],
        password: SimpleConfig.bitbucket[:password]
      )
      JSON.parse(response, symbolize_names: true)
    rescue StandardError => e
      LOGGER.fatal "Got error when try to put some info in PR:#{id} from #{remote.url.repo}"
      LOGGER.fatal "Error: #{e.response}"
      exit(1)
    end
  end
end
