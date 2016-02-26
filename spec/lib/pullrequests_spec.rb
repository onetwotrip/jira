require 'spec_helper'
describe JIRA::PullRequest do
  def create_test_object!(data)
    git_double = double(:git_double)
    allow(Git).to receive(:get_branch) { git_double }
    allow(git_double).to receive(:fetch)
    allow(git_double).to receive(:merge)
    described_class.new data
  end

  before :each do
    data =
      { 'source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0003' },
        'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
        'status' => 'CANCEL' }
    @pr = create_test_object! data
  end

  it '.new returns false with invalid input' do
    data =
      { 'source' => { 'url' => 'https://bb.org/org/repo_one/branch/OTT-0004' },
        'destination' => { 'url' => 'https://bb.org/org/repo_two/branch/master' } }
    @pr = create_test_object! data
    expect(@pr).to be_empty
  end

  it '.src and .dst return URI::Git::Generic' do
    expect(@pr.src.class).to eq(URI::Git::Generic)
    expect(@pr.dst.class).to eq(URI::Git::Generic)
  end
end

describe JIRA::PullRequests do
  before :each do
    @pullreq_double = double(:pullreq_double)
    allow(@pullreq_double).to receive(:instance_of?).with(JIRA::PullRequest) { true }
    allow(@pullreq_double).to receive(:valid?) { true }
    @prs = described_class.new
  end

  it '.valid? with PR returns true' do
    pr_data =
      { 'source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0001' },
        'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
        'status' => 'OPEN' }
    allow(@pullreq_double).to receive(:pr) { pr_data }
    @prs.add @pullreq_double
    expect(@prs.valid?).to eq true
  end
  it '.valid? without PR returns false' do
    allow(@pullreq_double).to receive(:pr) { nil }
    @prs.add @pullreq_double
    expect(@prs.valid?).to eq false
  end
  it '.valid? of equal PR returns false' do
    pr_data =
      { 'source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0001' },
        'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
        'status' => 'OPEN' }
    allow(@pullreq_double).to receive(:pr) { pr_data }
    @prs.add @pullreq_double
    @prs.add @pullreq_double
    expect(@prs.valid?).to eq false
  end

  it '.add method calls .valid? method of each PR' do
    pr_data =
      { 'source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0001' },
        'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
        'status' => 'OPEN' }
    allow(@pullreq_double).to receive(:pr) { pr_data }
    @prs.add @pullreq_double
  end

  it '.add method fails if argument is not PullRequest' do
    expect { @prs.add 'String' }.to raise_error(TypeError)
  end

  it '.each returns PullRequest' do
    pr_data =
      { 'source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0001' },
        'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
        'status' => 'OPEN' }
    allow(@pullreq_double).to receive(:pr) { pr_data }
    @prs.add @pullreq_double
    @prs.each { |i| expect(i.class).to eq JIRA::PullRequest }
  end

  it '.filter_by_* returns self' do
    allow(@pullreq_double).to receive(:pr) do
      Hash('source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0001' },
           'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
           'status' => 'OPEN')
    end
    @prs.add @pullreq_double
    prs_obj_id = @prs.object_id
    expect(@prs.filter_by_status('OPEN').object_id).to eq prs_obj_id
  end

  it '.filter_by_status(OPEN) returns OPEN PullRequests' do
    allow(@pullreq_double).to receive(:pr) do
      Hash('source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0001' },
           'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
           'status' => 'OPEN')
    end
    @prs.add @pullreq_double
    pullreq2_double = double(:pullreq2_double)
    allow(pullreq2_double).to receive(:instance_of?).with(JIRA::PullRequest) { true }
    allow(pullreq2_double).to receive(:valid?) { true }
    allow(pullreq2_double).to receive(:pr) do
      Hash('source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0002' },
           'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
           'status' => 'CLOSE')
    end
    @prs.add pullreq2_double
    @prs.filter_by_status('OPEN').prs
    expect(@prs.prs).to include @pullreq_double
    expect(@prs.prs).not_to include pullreq2_double
  end

  it '.filter_by_source_url(url) returns PullRequests with source url' do
    allow(@pullreq_double).to receive(:pr) do
      Hash('source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0001' },
           'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
           'status' => 'OPEN')
    end
    @prs.add @pullreq_double
    pullreq2_double = double(:pullreq2_double)
    allow(pullreq2_double).to receive(:instance_of?).with(JIRA::PullRequest) { true }
    allow(pullreq2_double).to receive(:valid?) { true }
    allow(pullreq2_double).to receive(:pr) do
      Hash('source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0002' },
           'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
           'status' => 'CLOSE')
    end
    @prs.add pullreq2_double
    @prs.filter_by_source_url(@pullreq_double.pr['source']['url'])
    expect(@prs.prs).to include @pullreq_double
    expect(@prs.prs).not_to include pullreq2_double
  end

  it '.grep_by_* should return grepped PullRequests' do
    allow(@pullreq_double).to receive(:pr) do
      Hash('source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0001' },
           'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
           'status' => 'OPEN')
    end
    @prs.add @pullreq_double
    pullreq2_double = double(:pullreq2_double)
    allow(pullreq2_double).to receive(:instance_of?).with(JIRA::PullRequest) { true }
    allow(pullreq2_double).to receive(:valid?) { true }
    allow(pullreq2_double).to receive(:pr) do
      Hash('source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0002' },
           'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
           'status' => 'CLOSE')
    end
    @prs.add pullreq2_double
    grep = @prs.grep_by_source_url(@pullreq_double.pr['source']['url'])

    expect(grep.prs).to include @pullreq_double
    expect(grep.prs).not_to include pullreq2_double
  end

  it '.method_missing calls super' do
    expect { subject.non_existed }.to raise_error(NoMethodError)
  end
end
