require 'scenarios'
module Scenarios
  ##
  # Check is auto test release branch exist scenario
  class PrepareReleaseBranch
    def run
      jira  = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info "Try to get all release branch from ticket #{issue.key}"
      release_branch = ''
      issue.related['branches'].each do |branch|
        if branch['repository']['name'].include? 'avia_api_rspec' # rubocop:disable Style/Next
          LOGGER.info "Found auto test branch: #{branch['name']}"
          release_branch = branch['name']
          break
        end
      end
      if release_branch.empty?
        default_branch = 'master'
        LOGGER.warn "Auto test branch din't find, so i will take '#{default_branch}' branch by default"
        release_branch = default_branch
      end
      LOGGER.info 'Prepare file with info'
      Ott::Helpers.export_to_file("BRANCH=#{release_branch}", 'test_branch')
      LOGGER.info 'Success!'
    end
  end
end
