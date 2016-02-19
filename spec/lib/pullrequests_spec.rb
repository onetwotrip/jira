require 'spec_helper'
describe JIRA::PullRequest do
  subject do
    pr = { 'source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0003' },
           'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
           'status' => 'CANCEL' }
    described_class.new pr
  end
  it '.src and .dst should return URI::Git::Generic' do
    expect(subject.src.class).to eq(URI::Git::Generic)
    expect(subject.dst.class).to eq(URI::Git::Generic)
  end
end

describe JIRA::PullRequests do
  subject do
    open_prs = [
      { 'source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0001' },
        'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
        'status' => 'OPEN' },
      { 'source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0002' },
        'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
        'status' => 'OPEN' }]
    cancel_prs = [
      { 'source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0003' },
        'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
        'status' => 'CANCEL' }]
    described_class.new open_prs + cancel_prs
  end

  it { expect be_valid }
  it 'not be valid' do
    subject.clear
    is_expected.to_not be_valid
  end
  it_behaves_like 'add and fail', 'source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0001' },
                                  'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' }
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

  it '.filter_by_* should change PullRequests' do
    expected = subject[0]
    url = expected['source']['url']
    subject.filter_by_status('OPEN')
      .filter_by_source_url(url)
    expect(subject).to eq [expected]
  end
  it '.grep_by_* should return grepped PullRequests' do
    url = subject[0]['source']['url']
    expect(
      subject.grep_by_status('OPEN')
             .grep_by_source_url(url)
    ).to eq [subject[0]]
  end

  it '.method_missing calls super' do
    expect { subject.non_existed }.to raise_error(NoMethodError)
  end
end
