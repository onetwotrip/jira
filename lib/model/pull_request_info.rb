# Jira Pull Request info
class PullRequestInfo
  attr_accessor :id, :repo, :title, :status, :url, :branch

  def initialize(id, repo, branch, title, status)
    @id = id
    @repo = repo
    @branch = branch
    @title = title
    @status = status
    @url = "https://bitbucket.org/OneTwoTrip/#{repo}/pull-requests/#{id}/#{branch}"
  end
end