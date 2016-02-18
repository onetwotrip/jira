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
  # suppress console output during rspec tests
  original_stderr = $stderr
  original_stdout = $stdout
  config.before(:all) do
    # Redirect stderr and stdout
    $stderr = File.open(File::NULL, 'w')
    $stdout = File.open(File::NULL, 'w')
  end
  config.after(:all) do
    $stderr = original_stderr
    $stdout = original_stdout
  end
end

shared_examples_for 'add and fail' do |pushed|
  it 'push it to the fail' do
    subject.add pushed
    should_not be_valid
  end
end
