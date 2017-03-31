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
  end

  # This module represents CheckBranchesBuildStatuses
  # :nocov:
  module CheckBranchesBuildStatuses
    def self.run(issue)
      issue.branches.each do |branch|
        branch_path = "#{branch.repo_owner}/#{branch.repo_slug}/#{branch.name}"
        LOGGER.info "Check Branch: #{branch_path}"
        branch_states = branch.commits.take(1).first.build_statuses.collect.map(&:state)
        if branch_states.empty?
          LOGGER.warn "Branch #{branch_path} doesn't have builds"
        elsif branch_states.delete_if { |s| s == 'SUCCESSFUL' }.any?
          LOGGER.error "Branch #{branch_path} has buildfail"
        end
      end
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
      if mailer.mails.empty?
        puts 'CodeReview: No changes for review'
      else
        mailer.sendmail
      end
    end
  end
end
