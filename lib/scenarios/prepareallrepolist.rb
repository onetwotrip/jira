module Scenarios
  ##
  # Prepare released repos and write to file
  class PrepareAllRepoList
    def run
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      # noinspection RubyArgCount
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info("Start work with #{issue.key}")
      result = ""
      issue.branches.each do |branch|
        result += ",#{branch.repo_slug}"
      end
      result = result[1..] # delete first comma
      LOGGER.info("Find repos: #{result}")


      Ott::Helpers.export_to_file(result, 'repo_list.txt')
    end
  end
end