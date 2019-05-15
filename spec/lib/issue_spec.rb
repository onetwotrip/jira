require 'spec_helper'

describe JIRA::Resource::Issue do # rubocop:disable Metrics/BlockLength
  let(:model) do
    client_options = {
      useremail: 'User',
      token: 'Pass',
      site: 'http://site.org',
      context_path: '/context'
    }
    jira = double(
      JIRA::Client, options: client_options,
                    Transition: JIRA::Resource::Transition,
                    Issue: JIRA::Resource::Issue
    )
    issue = JIRA::Resource::Issue.new(jira)
    issue.instance_variable_set(:@attrs, fields: { key: 'ISSUE' }, 'key' => 'ISSUE-001')
    issue
  end

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
      useremail: 'User',
      token: 'Pass',
      site: 'http://site.org',
      context_path: '/context'
    }
    @jira = double(
      JIRA::Client, options: client_options,
                    Transition: JIRA::Resource::Transition,
                    Issue: JIRA::Resource::Issue
    )
  end

  describe 'rollback' do
    subject { model.rollback }
    it do
      allow(model).to receive(:has_transition?).and_return(true)
      allow(model).to receive(:transition).and_return(true)
      branch = double(Tinybucket::Model::Branch, name: '-pre',
                                                 target: { 'repository' => { 'full_name' => 'owner/repo' } },
                                                 destroy: true)
      allow(model).to receive(:branches).and_return([branch])
      pr = double(Tinybucket::Model::PullRequest, title: 'Test PR',
                                                  state: 'OPEN',
                                                  destination: { 'repository' => { 'full_name' => 'owner/repo' } },
                                                  decline: true)
      allow(model).to receive(:api_pullrequests).and_return([pr])
      expect(subject)
      expect(branch).to have_received(:destroy)
      expect(pr).to     have_received(:decline)
    end
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
    expect(subj.to_s).to eq 'http://site.org/context/path'
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

  it '.related returns related data' do
    expected = { 'detail' => [{ 'pullRequests' => [], 'branches' => [] }] }
    issue = JIRA::Resource::Issue.new(@jira)
    allow(RestClient::Request).to receive(:execute).and_return(expected.to_json)
    expect(issue.related).to eq(expected['detail'].first)
  end

  it '.related returns related data with not empty_pr' do
    expected = { 'detail' => [{ 'pullRequests' => ['url' => 'https://bb.org/{}/{test}/pull-requests',
                                                   'name' => 'OneTwoTrip/test',
                                                   'source' => { 'url' => 'https://bb.org/{}/{test}/pull-requests' },
                                                   'destination' => { 'url' => 'dasdasd' }],
                                'branches' => ['repository' => { 'name' => 'test',
                                                                 'url' => 'https://bb.org/{}/{test}' }] }] }
    issue = JIRA::Resource::Issue.new(@jira)
    allow(RestClient::Request).to receive(:execute).and_return(expected.to_json)
    expect(issue.related['pullRequests'].first['source']['url']).to eq('https://bitbucket.org/OneTwoTrip/test/branch/')
  end

  it '.related returns related data with not empty_branches' do
    expected = { 'detail' => [{ 'branches' => ['repository' => { 'name' => 'test',
                                                                 'url' => 'https://bb.org/{}/{test}' }],
                                'pullRequests' => [] }] }
    issue = JIRA::Resource::Issue.new(@jira)
    allow(RestClient::Request).to receive(:execute).and_return(expected.to_json)
    expect(issue.related['branches'].first['url']).to eq('https://bitbucket.org/OneTwoTrip/test/branch/')
  end

  it '.post_comment calls comment.save' do
    expect_any_instance_of(JIRA::Base).to receive(:save).and_return(true)
    transition = double(JIRA::Resource::Transition, name: 'name', id: 1234)
    allow_any_instance_of(JIRA::Resource::Issue).to receive(:status).and_return(transition)

    issue = JIRA::Resource::Issue.new(@jira)
    issue.post_comment 'BODY'
  end

  it '.tags?(key, value) should returns bool' do
    key = 'customtags'
    val = 'value'
    issue = JIRA::Resource::Issue.new(@jira)
    issue.instance_variable_set(:@attrs,
                                'fields' => {
                                  'fields' => {
                                    key => [{ 'value' => val }]
                                  }
                                })
    expect(issue.tags?(key, val)).to eq true

    expect(issue.tags?(key, 'badval')).to eq false
    expect(issue.tags?('badkey', val)).to eq false
    expect(issue.tags?(nil, nil)).to eq false
  end

  it '.all_deployes should returns all dependent' do
    issue = JIRA::Resource::Issue.new(@jira)
    issue1 = issue.dup
    issue2 = issue.dup
    sub_issue = issue.dup

    allow(issue).to receive(:linked_issues).with('deployes').and_return [issue1, issue2]
    allow(issue1).to receive(:linked_issues).with('deployes').and_return [sub_issue]
    allow(issue2).to receive(:linked_issues).with('deployes').and_return []
    allow(sub_issue).to receive(:linked_issues).with('deployes').and_return []

    expect(issue.all_deployes.class.name).to eq 'Array'
    expect(issue.all_deployes).to include issue1, issue2, sub_issue
  end

  it '.all_labels should return all labels' do
    issue = JIRA::Resource::Issue.new(@jira)
    issue1    = issue.dup
    issue2    = issue.dup
    issue.instance_variable_set(:@attrs, fields: { key: 'ISSUE' }, 'key' => 'ISSUE-001')
    issue1.instance_variable_set(:@attrs, fields: { key: 'ISSUE_1' }, 'key' => 'ISSUE_1')
    issue2.instance_variable_set(:@attrs, fields: { key: 'ISSUE_2' }, 'key' => 'ISSUE_2')
    allow(issue).to receive(:linked_issues).with('deployes').and_return [issue1, issue2]
    allow_any_instance_of(JIRA::Resource::Issue).to receive(:related).and_return(
      open_pr = { 'branches' => [
        { 'repository' => { 'name' => 'avia' } },
        { 'repository' => { 'name' => 'railways' } }
      ] }
    )
    expect(issue.all_labels).to eq(%w[avia railways])
  end

  it '.all_deployes should returns filtered issues' do # rubocop:disable Metrics/BlockLength
    issue     = JIRA::Resource::Issue.new(@jira)
    issue1    = issue.dup
    issue2    = issue.dup
    sub_issue = issue.dup
    issue.instance_variable_set(:@attrs, fields: { key: 'ISSUE' }, 'key' => 'ISSUE')
    issue1.instance_variable_set(:@attrs, fields: { key: 'ISSUE_1' }, 'key' => 'ISSUE_1')
    issue2.instance_variable_set(:@attrs, fields: { key: 'ISSUE_2' }, 'key' => 'ISSUE_2')
    sub_issue.instance_variable_set(:@attrs, fields: { key: 'SUB_ISSUE' }, 'key' => 'SUB_ISSUE')

    allow(issue).to receive(:linked_issues).with('deployes').and_return [issue1, issue2]
    allow(issue1).to receive(:linked_issues).with('deployes').and_return [sub_issue]
    allow(issue2).to receive(:linked_issues).with('deployes').and_return []
    allow(sub_issue).to receive(:linked_issues).with('deployes').and_return []

    allow(issue).to receive(:tags?).with('customtags', 'value').and_return true
    allow(issue1).to receive(:tags?).with('customtags', 'value').and_return false
    allow(issue2).to receive(:tags?).with('customtags', 'value').and_return false
    allow(sub_issue).to receive(:tags?).with('customtags', 'value').and_return false

    expect(issue.all_deployes { |i| !i.tags?('customtags', 'value') }).to contain_exactly

    allow(issue).to receive(:tags?).with('customtags', 'value').and_return false
    allow(issue1).to receive(:tags?).with('customtags', 'value').and_return false
    allow(issue2).to receive(:tags?).with('customtags', 'value').and_return true
    allow(sub_issue).to receive(:tags?).with('customtags', 'value').and_return true

    expect(issue.all_deployes { |i| !i.tags?('customtags', 'value') }).to contain_exactly issue1

    allow(issue).to receive(:tags?).with('customtags', 'value').and_return false
    allow(issue1).to receive(:tags?).with('customtags', 'value').and_return true
    allow(issue2).to receive(:tags?).with('customtags', 'value').and_return false
    allow(sub_issue).to receive(:tags?).with('customtags', 'value').and_return true

    expect(issue.all_deployes { |i| !i.tags?('customtags', 'value') }).to contain_exactly issue2
  end

  it '.tags? return true if tag available' do
    issue = JIRA::Resource::Issue.new(@jira)
    issue.instance_variable_set(:@attrs, 'fields' => {
                                  'key' => 'ID',
                                  'fields' => {}
                                })
    expect(issue.tags?('customtags', 'value')).to eq false

    issue.instance_variable_set(:@attrs, 'fields' => {
                                  'key' => 'ID',
                                  'fields' => {
                                    'customtags' => [
                                      { 'value' => 'value' }
                                    ]
                                  }
                                })
    expect(issue.tags?('customtags', 'value')).to eq true
  end
end
