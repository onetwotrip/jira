# Global requirements
require 'addressable/uri'
require 'colorize'
require 'git'
require 'git_diff_parser'
require 'issue'
require 'java-properties'
require 'jira-ruby'
require 'json'
require 'yaml'
require 'ottinfra/sendmail'
require 'pp'
require 'rest-client'
require 'sendgrid-ruby'
require 'simple_config'
require 'terminal-table'

require 'check'
require 'issue'
require 'repo'

require 'common/logger'
require 'common/util.rb'

# Scenarios
Dir[__dir__ + '/scenarios/*.rb'].each { |file| require file }

# kill Timeout module for debug bug in Rubymine
if $LOADED_FEATURES.any? { |f| f.include? 'debase' }
  # Add timeout for debug mode
  module Timeout
    def timeout(sec, _klass = nil)
      yield(sec)
    end

    module_function :timeout
  end
end
