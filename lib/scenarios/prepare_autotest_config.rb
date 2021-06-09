module Scenarios

  # Prepare config for autotest branch + tags for execute
  class PrepareAutotestConfig

    def run
      jira = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      LOGGER.info("Start work with #{Ott::Helpers.jira_link(issue.key)}")
      LOGGER.info("Start prepare release branch")
      branch = Scenarios::PrepareReleaseBranch.new.run
      LOGGER.info("Success! #{branch}")
      LOGGER.info("Try to get repo list")
      repos = Scenarios::PrepareAllRepoList.new.run(release_skip: true)
      LOGGER.info("Success! repo: #{repos}")
      config = "#{branch};ARGS="
      if repos.empty?
        LOGGER.error("Repo is empty, but it shouldn't")
        exit(1)
      else
        repos.split(',').each { |repo| config += " --tag #{repo}," }
      end
      LOGGER.info("Final config is: #{config}")
    end

  end

end