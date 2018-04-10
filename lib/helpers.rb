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
      issue.branches.each do |branch|
        branch_path = "#{branch.repo_owner}/#{branch.repo_slug}/#{branch.name}"
        LOGGER.info "Check Branch: #{branch_path}"
        if branch_states(branch).empty?
          LOGGER.warn "Branch #{branch_path} doesn't have builds"
        else
          while branch_states(branch).select { |s| s == 'INPROGRESS' }.any?
            LOGGER.info "Branch #{branch_path} state INPROGRESS. Waiting..."
            sleep 60
          end
          LOGGER.error "Branch #{branch_path} has no successful status" if branch_states(branch).delete_if { |s| s == 'SUCCESSFUL' }.any?
        end
      end
    end

    def self.branch_states(branch)
      branch.commits.take(1).first.build_statuses.collect.map(&:state)
    end
  end
  # This module represents StrictControl
  module StrictControl
    def self.run(issue)
      sendmail get_stricts(issue)
    end

    def self.get_stricts(issue)
      strict_control = []
      issue.api_pullrequests.select { |pr| pr.state == 'OPEN' }.each do |pr|
        LOGGER.info "Check PR: #{pr.title}"
        repo = issue.repo pr.destination['repository']['links']['html']['href']
        pr.commits.each do |commit|
          GitDiffParser.parse(repo.diff(commit.hash)).each do |patch|
            JSON.parse(ENV.fetch('STRICT_FILES', '{}')).each do |strict_path|
              next unless patch.file.start_with?(strict_path)
              strict_control.push(author: commit.author['raw'].html_safe,
                                  url: commit.links['html']['href'].html_safe,
                                  file: patch.file.html_safe)
              LOGGER.info "StrictControl: #{patch.file}"
            end
          end
        end
      end
      strict_control
    end

    def self.sendmail(strict_control)
      b = binding
      b.local_variable_set(:changes, strict_control)
      mailer = OttInfra::SendMail.new SimpleConfig.sendgrid.to_h
      mailer.add SimpleConfig.sendgrid.to_h.merge message: ERB.new(File.read("#{Ott::Helpers.root}/views/review_mail.erb")).result(b)
      if strict_control.empty?
        LOGGER.info 'CodeReview: No changes for review'
      else
        mailer.sendmail
      end
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
