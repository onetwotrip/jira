require 'spec_helper'
require 'scenarios'

describe Scenarios::CreateRelease do
  before :each do
    client_options = {
      username: 'User',
      password: 'Pass',
      site: 'http://site.org',
      context_path: '/context'
    }
    @jira = double(
      JIRA::Client, options: client_options,
                    Project: JIRA::Resource::Project,
                    Issue: JIRA::Resource::Issue
    )
    SimpleConfig.instance_variable_set(:@c, nil)
    @scenario = Scenarios::CreateRelease.new
  end

  it 'should failed if not release params' do
    expect { @scenario.run }.to raise_exception(SystemExit)
  end

  it 'should failed if not filter or tasks params' do
    allow(ENV).to receive(:each).and_yield('RELEASE_NAME', 'true')
    expect { @scenario.run }.to raise_exception(SystemExit)
  end
end
