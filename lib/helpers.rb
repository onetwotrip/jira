require_relative './common/jenkins'
##
# This module represents Ott methods
module Ott
  ##
  # This module represents helper methods
  module Helpers
    @root = Pathname.new(Dir.pwd)

    def self.root
      @root
    end

    def self.diffed_lines(diff)
      ranges = []
      diff.each_line do |l|
        return [] if l =~ /^Binary files ([^ ]+) and ([^ ]+) differ$/ # skip binary files
        return [0..1] if l =~ /@@ -0,0 +\d+ @@/ # return [0..1] for a new file
        next unless (md = /^@@ -\d+(?:,\d+)? \+(\d+),(\d+) @@/.match(l))

        ranges << ((md[1].to_i)..(md[1].to_i + md[2].to_i))
      end
      puts "#{diff}\n Diff without marks or unknown marks!" if ranges.empty? && !diff.empty?
      ranges
    end

    # export any data for Jenkins later use
    def self.export_to_file(data, custom_filename = nil)
      file_name = custom_filename || 'ruby_script_output.txt'
      file_path = File.join(@root, file_name)

      LOGGER.info "Exporting to #{file_path}"
      # creating file in root, overwriting anything
      File.open(file_path, 'w+') do |file|
        file << data
      end
      LOGGER.info "Exported #{File.size(file_path)} bytes to '#{file_path}'"
    end
  end

  # Check Build Status
  module CheckBuildStatuses
    # For all Branches in ticket
    def self.for_all_branches(issue)
      check(issue)
    end

    # For all branches which contain open PR in ticket
    def self.for_open_pull_request(issue)
      check(issue, is_open_pr: true)
    end

    def self.for_mobile_open_pull_request(issue)
      check(issue, is_open_pr: true, mobile: true)
    end

    # issue - Jira tiket number
    # is_open_pr - Does it have to check build for open PR?
    # timeout - time to try to get build last status. Calculate as timeout(seconds) = timeout(value)*10
    # mobile - is it for mobile branch check. It has symbol / in branch name and should handle in another way
    def self.check(issue, is_open_pr: false, timeout: 180, mobile: false)
      white_list = ENV['REPO_WHITE_LIST'] || []
      failed_builds = []
      branches_array = issue.branches
      branches_array = issue.api_pullrequests if is_open_pr
      branches_array.each do |item|
        repo_name = item.repo_slug
        branch_name = if is_open_pr
                        item.source['branch']['name']
                      else
                        item.name
                      end
        build_url = "https://build.twiket.com/job/#{repo_name}/job/#{branch_name}/"
        LOGGER.info "Check #{repo_name}: #{branch_name}"
        if white_list.include? repo_name
          LOGGER.warn "Repo: #{repo_name} in white_list: #{white_list}. Go next!"
          next
        end

        # Need some wait while Jenkins get hook from BB and start build
        10.times do
          if mobile
            # Mobile project has build from open PR, not branch. So we need use PR id for url
            Jenkins.get_last_build_status(repo_name, "PR-#{item.id}")
          else
            Jenkins.get_last_build_status(repo_name, branch_name)
          end
          break
        rescue StandardError => e
          LOGGER.warn 'Wait while Jenkins start build...'
          sleep(6)
          next
        end

        begin
          result = if mobile
                     # Mobile project has build from open PR, not branch. So we need use PR id for url
                     Jenkins.get_last_build_status(repo_name, "PR-#{item.id}")
                   else
                     Jenkins.get_last_build_status(repo_name, branch_name)
                   end
          counter = 0
          until result
            LOGGER.warn "Build #{build_url} has status IN PROGRESS... - #{counter}/#{timeout}"
            result = if mobile
                       # Mobile project has build from open PR, not branch. So we need use PR id for url
                       Jenkins.get_last_build_status(repo_name, "PR-#{item.id}")
                     else
                       Jenkins.get_last_build_status(repo_name, branch_name)
                     end
            sleep(10) # 10 sec
            counter += 1
            next if counter < timeout

            issue.post_comment <<-BODY
                {panel:title=Build notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
                  Не удалось дождаться окончания сборки [билда|#{build_url}]
                {panel}
            BODY
            issue.transition 'Wait for reply'
            exit(1)

          end
          LOGGER.info "Branch was built for #{counter * 10} seconds" if counter.positive?
          case result
            when 'SUCCESS'
              LOGGER.info "#{repo_name}: #{branch_name} SUCCESS!"
              next
            when 'FAILURE'
              LOGGER.error "#{build_url} - FAILURE!"
              failed_builds << build_url
              next
            else
              LOGGER.error "#{build_url} - strange status!"
              failed_builds << build_url
              next
          end
        rescue StandardError => e
          LOGGER.error e.message.red
          failed_builds << build_url
          next
        end
      end
      if failed_builds.empty?
        LOGGER.info 'All builds success!'
        issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Проверка сборок в ветках завершена успешна (/)
      {panel}
        BODY
      else
        issue.post_comment <<-BODY
                {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  Next builds has FAILURE status: #{failed_builds}
                {panel}
        BODY
        # For ticket
        issue.transition 'Reopened'
        # For infra release
        issue.transition 'Build Failed'
        LOGGER.error 'Found some branch with FAILURE status'
        exit(1)
      end
    end

    def self.branch_states(branch)
      result = []
      branch.commits.take(1).first.build_statuses.collect.each do |s|
        result << s.state if s.name.include?(branch.name)
      end
      result
    end
  end

  # This module represents CheckPullRequests
  module CheckPullRequests
    def self.run(issue)
      pullrequests = issue.pullrequests(SimpleConfig.git.to_h)
                          .filter_by_status('OPEN')
                          .filter_by_source_url(issue.key)

      return if pullrequests.valid?

      issue.post_comment <<-BODY
              {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
                  Нет валидных PR(Статус: Open и с номером задачи в названии)
              {panel}
      BODY
    end
  end
end
#
module Tinybucket
  module Api
    module Helper
      module ApiHelper
        private

        def next_proc(method, options)
          lambda do |next_options|
            send(method, options.merge(next_options))
          end
        end

        def urlencode(v, key)
          if v.blank? || (escaped = CGI.escape(v.to_s)).blank?
            msg = "Invalid #{key} parameter. (#{v})"
            raise ArgumentError, msg
          end
          # ADR and IOS use / in branch name, so we have to skip it for CGI.escape
          escaped = v.to_s if v.to_s.include?('feature/')
          escaped
        end

        def build_path(base_path, *components)
          components.reduce(base_path) do |path, component|
            part = if component.is_a?(Array)
                     urlencode(*component)
                   else
                     component.to_s
                   end
            path + '/' + part
          end
        rescue ArgumentError => e
          raise ArgumentError, "Failed to build request URL: #{e}"
        end

        module_function :build_path, :next_proc, :urlencode
      end
    end
  end
end
