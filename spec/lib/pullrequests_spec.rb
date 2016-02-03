require 'spec_helper'
describe JIRA::PullRequests do
  subject do
    described_class.new [{ 'source' => { 'url' => 'A' } },
                         { 'source' => { 'url' => 'B' } },
                         { 'source' => { 'url' => 'C' } }]
  end
  it { should be_valid }
  it 'not be valid' do
    subject.clear
    is_expected.to_not be_valid
  end
  it_behaves_like 'push and fail', String
  it_behaves_like 'push and fail', Hash['source' => { 'url' => 'A' }]
  it_behaves_like 'push and fail', Hash['source' => { 'url2' => 'A' }]
end
