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
        puts "Error: #{e}; URL: #{url}; PARAMS: #{request}"
      end
    end
  end
end
