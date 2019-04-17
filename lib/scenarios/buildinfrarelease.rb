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
      LOGGER.info 'Wait while build will start'
      sleep 45
      LOGGER.info "Check build status #{@opts[:release]}"
      Ott::CheckBranchesBuildStatuses.run(@opts[:release])
      LOGGER.info "Freeze release #{@opts[:release]}"
      Scenarios::FreezeRelease.new.run
      LOGGER.info 'Wait while build will start'
      sleep 45
      LOGGER.info "Review release #{@opts[:release]}"
      Scenarios::ReviewRelease.new.run
    end
  end
end
