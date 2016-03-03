require 'spec_helper'
require 'yaml'

describe JIRA::Resource::Issue do
  open_pr = { 'pullRequests' => [
    { 'source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0001' },
      'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
      'status' => 'OPEN' }
  ] }
  config_git = { reviewer: 'Reviewer',
                 reviewer_key: 'reviewer.mail',
                 workdir: './workdir' }
  before :each do
    client_options = {
      username: 'User',
      password: 'Pass',
      site: 'http://site.org',
      context_path: '/context'
    }
    @jira = double(
      JIRA::Client, options: client_options,
                    Transition: JIRA::Resource::Transition,
                    Issue: JIRA::Resource::Issue
    )
  end

  it '.pullrequests should return PullRequests' do
    allow_any_instance_of(JIRA::Resource::Issue).to receive(:related)
      .and_return(open_pr)
    issue = JIRA::Resource::Issue.new(@jira)
    expect(issue.pullrequests(config_git).class).to eq(JIRA::PullRequests)
  end

  it '.create_endpoint should returns Addressable::URI' do
    issue = JIRA::Resource::Issue.new(@jira)
    subj = issue.create_endpoint('path')
    expect(subj.class).to eq Addressable::URI
    expect(subj.to_s).to eq 'http://User:Pass@site.org/context/path'
  end

  it '.get_transition_by_name should returns transition' do
    transition = double(JIRA::Resource::Transition, name: 'name')
    allow(JIRA::Resource::Transition).to receive(:all).and_return([transition])

    issue = JIRA::Resource::Issue.new(@jira)
    expect(issue.get_transition_by_name('name')).to eq transition
    expect(issue.has_transition?('name')).to be_truthy
  end

  it '.transition should returns transition' do
    transition = double(JIRA::Resource::Transition, name: 'name', id: 1234)
    allow(JIRA::Resource::Transition).to receive(:all).and_return([transition])
    allow_any_instance_of(JIRA::Base).to receive(:save!).and_return(true)

    issue = JIRA::Resource::Issue.new(@jira)
    issue.define_singleton_method(:key) { 'key' }
    expect(issue.transition('name')).to eq true
  end

  it '.link calls RestClient.post' do
    expect(RestClient).to receive(:post)
    issue = JIRA::Resource::Issue.new(@jira)
    issue.define_singleton_method(:key) { 'key' }
    issue.link
  end

  it '.related returns related data' do
    expected = { 'detail' => [{ 'pullRequests' => [] }] }
    issue = JIRA::Resource::Issue.new(@jira)
    allow(RestClient).to receive(:get).and_return(expected.to_json)
    expect(issue.related).to eq(expected['detail'].first)
  end

  it '.post_comment calls comment.save' do
    expect_any_instance_of(JIRA::Base).to receive(:save).and_return(true)
    transition = double(JIRA::Resource::Transition, name: 'name', id: 1234)
    allow_any_instance_of(JIRA::Resource::Issue).to receive(:status).and_return(transition)

    issue = JIRA::Resource::Issue.new(@jira)
    issue.post_comment 'BODY'
  end
end
