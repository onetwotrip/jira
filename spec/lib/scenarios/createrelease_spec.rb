require 'spec_helper'
require 'scenarios'

describe Scenarios::CreateRelease do
  jira_filter = '12341'
  jira_tasks = 'XXX-100,XYZ-101'
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

  it 'should failed if had HTTP error from search by filter' do
    issue = double
    allow(issue).to receive(:jql).with(any_args).and_throw(JIRA::HTTPError)
    expect(@scenario).to receive(:find_by_filter).with(issue, jira_filter).and_return []
    @scenario.find_by_filter(issue, jira_filter)
  end

  it 'should failed if had HTTP error from search by tasks' do
    issue = double
    allow(issue).to receive(:jql).with(any_args).and_throw(JIRA::HTTPError)
    expect(@scenario).to receive(:find_by_tasks).with(issue, jira_tasks).and_return []
    @scenario.find_by_tasks(issue, jira_tasks)
  end
end
