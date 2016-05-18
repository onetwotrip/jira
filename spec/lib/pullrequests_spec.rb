require 'spec_helper'
describe JIRA::PullRequests do
  before :each do
    @pullreq_double = double(:pullreq_double)
    allow(@pullreq_double).to receive(:instance_of?).with(JIRA::PullRequest) { true }
    allow(@pullreq_double).to receive(:valid?) { true }
    @prs = described_class.new
  end

  it '.tests_fails returns array of fail names' do
    @ok_test = double(:ok_double)
    allow(@ok_test).to receive(:name) { :ok }
    allow(@ok_test).to receive(:status) { true }
    allow(@ok_test).to receive(:code) { true }

    @fail_test = double(:fail_double)
    allow(@fail_test).to receive(:name) { :failed }
    allow(@fail_test).to receive(:status) { false }
    allow(@fail_test).to receive(:code) { false }

    allow(@pullreq_double).to receive(:tests) { [@ok_test, @fail_test] }

    @prs.add @pullreq_double
    expect(@prs.tests_fails).to match_array(:failed)
  end

  it '.tests_*' do
    @ok_test = double(:tests_double)
    allow(@ok_test).to receive(:name)   { :ok }
    allow(@ok_test).to receive(:status) { true }
    allow(@ok_test).to receive(:dryrun) { false }
    allow(@ok_test).to receive(:code) { true }

    @fail_test = double(:tests_double)
    allow(@fail_test).to receive(:name)   { :failed }
    allow(@fail_test).to receive(:status) { true }
    allow(@fail_test).to receive(:dryrun) { true }
    allow(@fail_test).to receive(:code) { false }

    allow(@pullreq_double).to receive(:test).with(:ok) { [@ok_test] }
    allow(@pullreq_double).to receive(:test).with(:failed) { [@fail_test] }

    @prs.add @pullreq_double

    expect(@prs.tests_dryrun(:ok)).to eq false
    expect(@prs.tests_dryrun(:failed)).to eq true

    expect(@prs.tests_status(:ok)).to eq true
    expect(@prs.tests_status(:failed)).to eq true

    expect(@prs.tests_code(:ok)).to eq true
    expect(@prs.tests_code(:failed)).to eq false

    expect(@prs.tests_status_string(:ok)).to eq 'PASSED'
    expect(@prs.tests_status_string(:failed)).to eq 'IGNORED (FAIL)'
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

  it '.each returns pullrequest enumerable' do
    pr_data =
      { 'source' => { 'url' => 'https://bb.org/org/repo/branch/OTT-0001' },
        'destination' => { 'url' => 'https://bb.org/org/repo/branch/master' },
        'status' => 'OPEN' }
    allow(@pullreq_double).to receive(:pr) { pr_data }
    @prs.add @pullreq_double
    @prs.each do |pr|
      expect(pr).to eq @pullreq_double
    end
  end

  it '.add method fails if argument is not PullRequest' do
    expect { @prs.add 'String' }.to raise_error(TypeError)
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
