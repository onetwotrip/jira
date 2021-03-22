require 'rest-client'
require 'json'

##
# For jenkins rest api
module Jenkins
  def self.get_last_build_status(repo_name, branch_name)
    url = "https://build.twiket.com/job/#{repo_name}/job/#{branch_name}/lastBuild/api/json?tree=result" # rubocop:disable Metrics/LineLength
    LOGGER.info "GET #{url}"
    response = RestClient::Request.execute(
      method: :get,
      url: url,
      user: SimpleConfig.jenkins[:user_email],
      password: SimpleConfig.jenkins[:token]
    )
    JSON.parse(response, symbolize_names: true)[:result]
  rescue StandardError => e
    LOGGER.fatal "Got error when try to get last build status for branch:#{branch_name} from repo: #{repo_name}"
    LOGGER.fatal "Error: #{e}"
    raise e
  end
end
