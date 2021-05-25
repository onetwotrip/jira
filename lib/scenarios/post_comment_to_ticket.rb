module Scenarios
  ##
  # Post comment to ticket
  class PostCommentToTicket
    def run
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info Ott::Helpers.jira_link(issue.key).to_s
      LOGGER.info "Try to post message: '#{ENV['MESSAGE']}' into ticket #{issue.key}"
      issue.post_comment ENV['MESSAGE']
    end
  end
end
