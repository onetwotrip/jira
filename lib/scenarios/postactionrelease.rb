module Scenarios
  ##
  # PostactionRelease scenario
  class PostactionRelease
    def run
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      # noinspection RubyArgCount
      issue = jira.Issue.find(SimpleConfig.jira.issue)

      pullrequests = issue.pullrequests(SimpleConfig.git.to_h)
                          .filter_by_status('OPEN')
                          .filter_by_source_url(SimpleConfig.jira.issue)

      unless pullrequests.valid?
        issue.post_comment p("ReviewRelease: #{pullrequests.valid_msg}")
        exit
      end

      pullrequests.each do |pr|
        # Checkout repo
        puts "Clone/Open with #{pr.dst} branch #{pr.dst.branch} and merge #{pr.src.branch} and push".green
        begin
          pr.repo.push
        rescue Git::GitExecuteError => e
          puts e.message.red
          next
        end
      end

      issue.linked_issues('deployes').each do |subissue|
        puts subissue.key
        # Transition to DONE
        subissue.transition 'To master' if subissue.get_transition_by_name 'To master'
      end
    end
  end
end
