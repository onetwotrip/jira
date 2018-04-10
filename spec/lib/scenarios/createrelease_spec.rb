require 'spec_helper'
require 'simple_config'

require 'scenarios/createrelease'

describe Scenarios::CreateRelease do # rubocop:disable Metrics/BlockLength
  let(:jira_filter) { '12341' }
  let(:jira_tasks) { 'XXX-100,XYZ-101' }
  response = Struct.new('JiraError', :body, :message, :body_exists).new('NOT_FOUND', 'Message', true)
  found_project = Struct.new('FoundProject', :id).new(1234)

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
    allow(issue).to receive(:jql).with(any_args).and_raise(JIRA::HTTPError.new(response))
    expect(@scenario.find_by_filter(issue, jira_filter)).to eq([])
  end

  it 'should failed if had HTTP error from search by tasks' do
    issue = double
    response = Struct.new('JiraError_tasks', :body, :message, :body_exists).new('NOT_FOUND', 'Message', true)
    allow(issue).to receive(:find).with(any_args).and_raise(JIRA::HTTPError.new(response))
    expect(@scenario.find_by_tasks(issue, jira_tasks)).to eq([])
  end

  it 'should failed if received HTTP error from jira when find project in release creation' do
    project = double
    issue = double
    response = Struct.new('JiraError_project', :body, :message, :body_exists).new('NOT_FOUND', 'Message', true)
    allow(project).to receive(:find).with(any_args).and_raise(JIRA::HTTPError.new(response))
    expect { @scenario.create_release_issue(project, issue) }.to raise_error(RuntimeError, 'Message')
  end

  it 'should failed if received HTTP error from jira when build release task' do
    project = double
    issue = double
    response = Struct.new('JiraError_build', :body, :message, :body_exists).new('NOT_FOUND', 'Message', true)
    allow(project).to receive(:find).with(any_args).and_return(id: 1234)
    allow(issue).to receive(:build).with(any_args).and_raise(JIRA::HTTPError.new(response))
    expect { @scenario.create_release_issue(project, issue) }.to raise_error(RuntimeError, 'Message')
  end

  it 'should failed if received HTTP error from jira when save created release' do
    project = double
    issue = double
    release = double
    response = Struct.new('JiraError_save', :body, :message, :body_exists).new('NOT_FOUND', 'Message', true)
    allow(project).to receive(:find).with(any_args).and_return(found_project)
    allow(issue).to receive(:build).with(any_args).and_return(release)
    allow(release).to receive(:save).with(any_args).and_raise(JIRA::HTTPError.new(response))
    expect { @scenario.create_release_issue(project, issue) }.to raise_error(RuntimeError, 'Message')
  end

  it 'should failed if received HTTP error from jira when fetch created release' do
    project = double
    issue = double
    release = double
    allow(project).to receive(:find).with(any_args).and_return(found_project)
    allow(issue).to receive(:build).with(any_args).and_return(release)
    allow(release).to receive(:save).with(any_args)
    allow(release).to receive(:fetch).with(any_args).and_raise(JIRA::HTTPError.new(response))
    expect { @scenario.create_release_issue(project, issue) }.to raise_error(RuntimeError, 'Message')
  end
end
