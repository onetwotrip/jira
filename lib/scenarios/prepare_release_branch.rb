require 'scenarios'
module Scenarios
  ##
  # Check is auto test release branch exist scenario
  class PrepareReleaseBranch
    def run
      jira  = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
      release_branch = if ENV['ADR']
        prepare_android_branch(issue)
      else
        prepare_tests_branch(issue)
      end

      LOGGER.info 'Prepare file with info'
      Ott::Helpers.export_to_file("BRANCH='#{release_branch}'", 'test_branch')
      LOGGER.info 'Success!'
      return "BRANCH=#{release_branch}"
    end

    def prepare_tests_branch(issue)
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
      release_branch
    end

    def prepare_android_branch(issue)
      LOGGER.info "Try to get all branch from ticket #{issue.key}"
      release_branch = ''
      issue.related['branches'].each do |branch|
        if branch['repository']['name'].include? 'android_ott' # rubocop:disable Style/Next
          LOGGER.info "Found android branches. Try to find release branch"
          next unless branch['name'].include? 'release/'
          LOGGER.info "Found release branches: #{branch['name']}"
          release_branch = branch['name']
          break
        end
      end
      if release_branch.empty?
        LOGGER.error "Can't find any release branch in #{issue.key}"
        exit(1)
      end
      release_branch
    end
  end
end
