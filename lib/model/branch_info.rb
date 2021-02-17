# Jira Branch info
class BranchInfo
  attr_accessor :repo, :name, :pr_status, :url

  def initialize(repo, name, pr_status)
    @repo = repo
    @name = name
    @pr_status = pr_status
    @url = "https://bitbucket.org/OneTwoTrip/#{repo}/branch/#{name}"
  end
end