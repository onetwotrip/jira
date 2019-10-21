require 'rest-client'
require 'json'

##
# This module extends Git
module Git
  ##
  # Add methods for Git::Base
  class Base
    # Create pull request from src branch to dst
    # By default: from local branch to master
    def create_pullrequest(username = nil, password = nil, src = current_branch, destination = 'master')
      request = { title: "#{src} #{remote.url.repo}",
                  source: { branch: { name: src },
                            repository: { full_name: remote.url.repo } },
                  destination: { branch: { name: destination } } }
      begin
        url = "https://#{username}:#{password}@api.bitbucket.org/2.0/repositories/#{remote.url.repo}/pullrequests"
        RestClient.post url, request.to_json, content_type: :json
      rescue StandardError => e
        LOGGER.fatal "Pullrequest didn't create"
        LOGGER.fatal "Error: #{e}; URL: #{url}; PARAMS: #{request}"
        exit(1)
      end
    end

    # :nocov:
    def new_create_pullrequest(src = current_branch, destination = 'master')
      request = { title: "#{src} #{remote.url.repo}",
                  source: { branch: { name: src },
                            repository: { full_name: remote.url.repo } },
                  destination: { branch: { name: destination } } }
      begin
        url = "https://bitbucket.org/!api/2.0/repositories/#{remote.url.repo}/pullrequests"
        LOGGER.info "POST #{url}"
        RestClient::Request.execute(
          method:   :post,
          url:      url,
          user: SimpleConfig.bitbucket[:username],
          password: SimpleConfig.bitbucket[:password],
          payload: request.to_json,
          headers: { content_type: :json }
        )
      rescue StandardError => e
        LOGGER.fatal "Pullrequest didn't create"
        LOGGER.fatal "Error: #{e}; URL: #{url}; PARAMS: #{request}"
        exit(1)
      end
    end

    def decline_pullrequest(username = nil, password = nil, pull_request_id = '')
      url = "https://#{username}:#{password}@api.bitbucket.org/2.0/repositories/#{remote.url.repo}/pullrequests/#{pull_request_id}/decline" # rubocop:disable Metrics/LineLength
      RestClient.post url, content_type: :json
    rescue StandardError => e
      LOGGER.fatal "Pullrequest didn't decline"
      LOGGER.fatal "Error: #{e}; URL: #{url}"
      exit(1)
    end

    def delete_branch(branch = current_branch)
      url = "https://bitbucket.org/!api/2.0/repositories/#{branch.repo_owner}/#{branch.repo_slug}/refs/branches/#{branch.name}" # rubocop:disable Metrics/LineLength
      LOGGER.info "DELETE #{url}"
      RestClient::Request.execute(
        method:   :delete,
        url:      url,
        user: SimpleConfig.bitbucket[:username],
        password: SimpleConfig.bitbucket[:password]
      )
    rescue StandardError => e
      LOGGER.fatal "Got error when try to delete branch #{branch.name}: #{e}"
      exit(1)
    end

    # :nocov:
    def get_pullrequests_diffstats(id)
      url = "https://bitbucket.org/!api/2.0/repositories/#{remote.url.repo}/pullrequests/#{id}/diffstat" # rubocop:disable Metrics/LineLength
      LOGGER.info "GET #{url}"
      response = RestClient::Request.execute(
        method:   :get,
        url:      url,
        user: SimpleConfig.bitbucket[:username],
        password: SimpleConfig.bitbucket[:password]
      )
      JSON.parse(response, symbolize_names: true)
    rescue StandardError => e
      LOGGER.fatal "Got error when try to get diff stats for PR:#{id} from #{remote.url.repo}"
      LOGGER.fatal "Error: #{e}"
      exit(1)
    end
  end
end
