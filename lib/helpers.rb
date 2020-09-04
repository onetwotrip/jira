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
        return [0..1] if l =~ /@@ -0,0 +\d+ @@/                       # return [0..1] for a new file
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
      counter = 1
      sleep_time = 60 # 60 секунд
      issue.branches.each do |branch|
        branch_path = "#{branch.repo_owner}/#{branch.repo_slug}/#{branch.name}"
        LOGGER.info "Check Build Branch Status: #{branch_path}"
        if branch_states(branch).empty?
          LOGGER.warn "Branch #{branch_path} doesn't have builds"
        else
          while branch_states(branch).select { |s| s == 'INPROGRESS' }.any?
            LOGGER.info "Branch #{branch_path} state INPROGRESS. Waiting..."
            if counter == 30 # максимальное время сборки: 30 минут
              issue.post_comment <<-BODY
      {panel:title=Build notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Не удалось дождаться окончания сборки билда
      {panel}
              BODY
              LOGGER.error "Build for #{branch_path} has no successful status"
              LOGGER.error "Move to 'WAIT FOR REPLY' status"
              issue.transition 'Needs reply'
              exit(1)
            end
            sleep sleep_time
            counter += 1
          end
          LOGGER.error "Branch #{branch_path} has no successful status" if branch_states(branch).delete_if { |s| s == 'SUCCESSFUL' }.any?
        end
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
      prs = issue.api_pullrequests
      if prs.empty?
        LOGGER.error 'Issue has no Pull Requests'
      else
        prs.each do |pr|
          LOGGER.info "Issue have PR #{pr.id}"
        end
      end
    end
  end
end
