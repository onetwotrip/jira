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

  # This module represents CheckBranchesBuildStatuses
  # :nocov:
  module CheckBranchesBuildStatuses
    def self.run(issue)
      white_list = ENV['REPO_WHITE_LIST'] || []
      failed_builds = []
      issue.api_pullrequests.each do |pr|
        repo_name = pr.repo_slug
        branch_name = pr.source['branch']['name']
        build_url = "https://build.twiket.com/job/#{repo_name}/job/#{branch_name}/"
        LOGGER.info "Check #{repo_name}: #{branch_name}"
        if white_list.include? repo_name
          LOGGER.warn "Repo: #{repo_name} in white_list: #{white_list}. Go next!"
          next
        end
        begin
          result = Jenkins.get_last_build_status(repo_name, branch_name)
          counter = 0
          timeout = 180 # ~30min for build
          until result
            LOGGER.warn "Build #{build_url} has status IN PROGRESS... - #{counter}/#{timeout}"
            result = Jenkins.get_last_build_status(repo_name, branch_name)
            sleep(10) # 10 sec
            counter += 1
            next if counter < 180

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
        issue.transition 'Needs reply'
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
