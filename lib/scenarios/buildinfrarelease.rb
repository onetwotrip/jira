require 'scenarios'
module Scenarios
  ##
  # BuildRelease scenario
  class BuildInfraRelease
    attr_reader :opts

    def initialize(opts)
      @opts = opts
    end

    def run
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)

      # Build release for INFRA team specific
      #Scenarios::BuildRelease.new(@opts).run(true)
      LOGGER.info 'Wait while build will start'
     # sleep 45
      LOGGER.info "Check build status #{@opts[:issue]}"
     # Ott::CheckBranchesBuildStatuses.run(issue)
      LOGGER.info "Freeze release #{@opts[:issue]}"
      Scenarios::FreezeRelease.new.run
      LOGGER.info 'Wait while build will start'
      sleep 45
      LOGGER.info "Review release #{@opts[:issue]}"
      Scenarios::ReviewRelease.new.run
    end
  end
end
