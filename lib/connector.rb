require 'jira'

class Connector  # :nodoc:
  class << self
    def initialize
    end

    def connect(opts)
      options = { username: opts[:username],
                  password: opts[:password],
                  site:     opts[:site],
                  context_path: opts[:contextpath],
                  auth_type: :basic
                }
      JIRA::Client.new(options)
    end
  end
end
