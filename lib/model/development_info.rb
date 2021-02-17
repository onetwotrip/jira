# Common class for info about development section in Jira ticket
class DevelopmentInfo
  attr_accessor :branches, :pr

  def initialize
    @branches = []
    @pr = []
  end
end