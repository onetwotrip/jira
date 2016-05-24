require 'bundler/setup'
require 'simplecov'
SimpleCov.start do
  SimpleCov.minimum_coverage_by_file 95
end
require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

require 'issue'
require 'repo'
require 'pullrequests'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
