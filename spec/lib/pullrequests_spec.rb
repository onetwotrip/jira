require 'spec_helper'
describe JIRA::PullRequests do
  subject do
    open_pr = [
      { 'source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0001' },
        'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
        'status' => 'OPEN' },
      { 'source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0002' },
        'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
        'status' => 'OPEN' }]
    cancel_pr = [
      { 'source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0003' },
        'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
        'status' => 'CANCEL' }]
    described_class.new open_pr + cancel_pr
  end

  it { expect be_valid }
  it 'not be valid' do
    subject.clear
    is_expected.to_not be_valid
  end
  it_behaves_like 'add and fail', 'source' => { 'url' => 'https://bb.org/org/repo_one/branch/OTT-0004' },
                                  'destination' => { 'url' => 'https://bb.org/org/repo_two/branch/master' }
  it_behaves_like 'add and fail', Hash['source' => { 'url' => 'A' }]
  it_behaves_like 'add and fail', Hash['source' => { 'url2' => 'A' }]
  it { subject.each { |i| expect(i.class).to eq JIRA::PullRequest } }

  it '.filter_by_* returns JIRA::PullRequests' do
    expect(subject.filter_by_status('OPEN').class).to eq JIRA::PullRequests
  end

  it '.filter_by_status(OPEN) returns OPEN PullRequests' do
    expect(subject.filter_by_status('OPEN')).to eq subject[0..1]
  end

  it '.filter_by_source_url(url) returns PullRequests with source url' do
    expect(
      subject.filter_by_source_url(subject[0]['source']['url'])
    ).to eq [subject[0]]
  end

  it '.filter_by_* should return filtered PullRequests' do
    url = subject[0]['source']['url']
    expect(
      subject.filter_by_status('OPEN')
             .filter_by_source_url(url)
    ).to eq [subject[0]]
  end
end
