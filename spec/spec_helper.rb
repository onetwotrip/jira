require 'bundler/setup'
require 'simplecov'
SimpleCov.start

require 'bitbucket/pullrequest'
require 'bitbucket'
require 'check'
require 'issue'
require 'repo'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
