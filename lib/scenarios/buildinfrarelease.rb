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
           Подробности в логе таски #{ENV['BUILD_URL']}
          {panel}
      BODY
    end

    def run
      # Build release for INFRA team specific
      step_id     = (ENV['STEP_ID'] || 0).to_i
      is_cd_build = ActiveModel::Type::Boolean.new.cast(ENV['CD_BUILD'] || false)
      flag        = false
      jira        = JIRA::Client.new SimpleConfig.jira.to_h
      issue       = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
      issue.transition 'CI Build' if is_cd_build

      if flag || step_id.zero?
        @should_stop_flag = Scenarios::BuildRelease.new(@opts).run(true)
        LOGGER.info 'Wait while build will start'
        sleep 20
        flag = true
      end

      if flag || (step_id == 1)
        LOGGER.info "Check build status #{@opts[:release]}"
        Ott::CheckBuildStatuses.for_all_branches(issue)
        flag = true
      end

      if flag || (step_id == 2)
        LOGGER.info "Check should_stop_flag: #{@should_stop_flag}"
        exit(0) if @should_stop_flag # Stop build if it has merge failed tickets
        LOGGER.info "Freeze release #{@opts[:release]}"
        Scenarios::FreezeRelease.new.run
        LOGGER.info 'Wait while build will start'
        sleep 20
        flag = true
      end

      if flag || (step_id == 3)
        LOGGER.info "Review release #{@opts[:release]}"
        Scenarios::ReviewRelease.new.run
      end

      LOGGER.info "Move ticket #{@opts[:release]} to Testing status"
      issue.transition 'Test Ready'
    rescue StandardError, SystemExit => _
      LOGGER.info("Exception: #{_}")
      exit(127) if _.status == 127
      LOGGER.error "Found some errors while release #{@opts[:release]} was building"
      if ticket_exist?(issue.key)
        issue.post_comment @error_comment
        issue.transition 'Build Failed'
      end
    end

    def ticket_exist?(key)
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      jira.Issue.find(key)
      true
    rescue JIRA::HTTPError => e
      if e.code == '404'
        LOGGER.warn "Ticket #{key} doesn't exist"
      else
        LOGGER.warn "Can't check if ticket #{key} exist. Reason: #{e.response.body}"
      end
      false
    end
  end
end
