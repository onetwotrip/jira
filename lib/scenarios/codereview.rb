module Scenarios
  ##
  # CodeReview scenario
  class CodeReview
    def run
      workdir = SimpleConfig.git.workdir
      Dir.mkdir workdir unless Dir.exist? workdir
      Dir.chdir workdir || './'

      unless SimpleConfig.jira.issue
        puts "CodeReview: No issue - no cry!\n"
        exit 2
      end

      # Getting issie
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      pullrequests = issue.pullrequests(SimpleConfig.git.to_h)
                          .filter_by_status('OPEN')
                          .filter_by_source_url(SimpleConfig.jira.issue)

      # Parsing/Validating PR
      unless pullrequests.valid?
        # Exit if pullrequests invalid
        issue.post_comment p("CodeReview: #{pullrequests.valid_msg}")
        exit
      end

      # Create mails
      mailer = OttInfra::SendMail.new SimpleConfig.sendgrid.to_h

      pullrequests.each do |review|
        review.send_notify do |msg|
          mailer.add SimpleConfig.sendgrid.to_h.merge message: msg
        end
      end

      # Send CodeReview
      if mailer.mails.empty?
        puts 'CodeReview: No changes for review'
      else
        mailer.sendmail
      end
    end
  end
end
