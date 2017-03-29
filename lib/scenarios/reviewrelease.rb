module Scenarios
  ##
  # ReviewRelease scenario
  class ReviewRelease
    STRICT_FILES = JSON.parse ENV.fetch('STRICT_FILES', '{}')
    def run
      strict_control = []
      LOGGER.info "Starting ReviewRelease for #{SimpleConfig.jira.issue}"
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      release = jira.Issue.find(SimpleConfig.jira.issue)
      # Check release status
      unless release.status.name == 'Code review'
        LOGGER.error "Issue '#{release.key}' doesn't have 'Code review' status"
      end
      # Check branches name/builds
      release.branches.each do |branch|
        branch_path = "#{branch.repo_owner}/#{branch.repo_slug}/#{branch.name}"
        unless branch.name.match "^#{release.key}-pre"
          LOGGER.error "Incorrect branch name: #{branch_path}"
        end
        branch_states = branch.commits.take(1).first.build_statuses.collect.map(&:state)
        if branch_states.empty?
          LOGGER.warn "Branch #{branch_path} doesn't have builds"
        elsif branch_states.delete_if { |s| s == 'SUCCESSFUL' }.any?
          LOGGER.error "Branch #{branch_path} has buildfail"
        end
      end
      # Check pullrequests status/stricts
      release.api_pullrequests.select { |pr| pr.state == 'OPEN' }.each do |pr|
        LOGGER.info "Check PR: #{pr.title}"
        unless pr.title.match "^#{release.key}"
          LOGGER.error "Incorrect PullRequest name: #{pr.title}"
        end
        repo = release.repo pr.destination['repository']['links']['html']['href']
        pr.commits.each do |commit|
          GitDiffParser.parse(repo.diff(commit.hash)).each do |patch|
            STRICT_FILES.each do |strict_path|
              next unless patch.file.start_with?(strict_path)
              strict_control.push(author: commit.author['raw'].html_safe,
                                  url: commit.links['html']['href'].html_safe,
                                  file: patch.file.html_safe)
              LOGGER.info "StrictControl: #{patch.file}"
            end
          end
        end
      end
      b = binding
      b.local_variable_set(:changes, strict_control)
      mailer = OttInfra::SendMail.new SimpleConfig.sendgrid.to_h
      mailer.add SimpleConfig.sendgrid.to_h.merge message: ERB.new(File.read("#{Ott::Helpers.root}/views/review_mail.erb")).result(b)
      if mailer.mails.empty?
        puts 'CodeReview: No changes for review'
      else
        mailer.sendmail
      end
      release.post_comment LOGGER.history_comment
    end
  end
end
