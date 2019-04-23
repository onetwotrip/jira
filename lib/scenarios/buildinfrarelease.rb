require 'scenarios'
module Scenarios
  ##
  # BuildRelease scenario
  class BuildInfraRelease
    attr_reader :opts

    def initialize(opts)
      @opts = opts

      @error_comment = <<-BODY
          {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
           Не удалось собрать билд (x)
           Подробности в логе таски https://jenkins.twiket.com/view/RELEASE/job/build_infra_release/
          {panel}
      BODY
    end

    def run
      # jira  = JIRA::Client.new SimpleConfig.jira.to_h
      # issue = jira.Issue.find(SimpleConfig.jira.issue)

      # Build release for INFRA team specific
      begin
        Scenarios::BuildRelease.new(@opts).run(true)
        LOGGER.info 'Wait while build will start'
        # sleep 45
        LOGGER.info "Check build status #{@opts[:release]}"
        # Ott::CheckBranchesBuildStatuses.run(issue)

        LOGGER.info "Freeze release #{@opts[:release]}"
        Scenarios::FreezeRelease.new.run
        LOGGER.info 'Wait while build will start'
       # sleep 45
        LOGGER.info "Review release #{@opts[:release]}"
       # Scenarios::ReviewRelease.new.run

      rescue StandardError => _
        issue.post_comment @error_comment
        issue.transition 'Build Failed'
      end
    end
  end
end
