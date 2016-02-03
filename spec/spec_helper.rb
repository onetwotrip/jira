require 'bundler/setup'
require 'simplecov'
SimpleCov.start

require 'bitbucket/pullrequest'
require 'bitbucket'
require 'check'
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

shared_examples_for 'push and fail' do |pushed|
  it 'push it to the fail' do
    subject.push pushed
    should_not be_valid
  end
end
