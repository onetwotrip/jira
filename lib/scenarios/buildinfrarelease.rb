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
      # Build release for INFRA team specific
      Scenarios::BuildRelease.new(@opts).run(true)
      sleep 45
      LOGGER.info "Review issue #{@opts[:release]}"
      Scenarios::ReviewIssue.new.run
      LOGGER.info "Freeze release #{@opts[:release]}"
      Scenarios::FreezeRelease.new.run
      sleep 45
      LOGGER.info "Review release #{@opts[:release]}"
      Scenarios::ReviewRelease.new.run
    end
  end
end
