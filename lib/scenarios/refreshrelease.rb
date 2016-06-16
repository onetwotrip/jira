module Scenarios
  ##
  # RefreshRelease scenario
  class RefreshRelease
    attr_reader :opts

    def initialize(opts)
      @opts = opts
    end

    def run
      STDOUT.sync = true

      options = { auth_type: :basic }.merge(opts.to_hash)
      client = JIRA::Client.new(options)
      release = client.Issue.find(opts[:release])
      release.deploys.each do |issue|
        puts issue.key
        # Transition to Merge Ready
        issue.transition 'Not merged' if issue.has_transition? 'Not merged'
      end
    end
  end
end
