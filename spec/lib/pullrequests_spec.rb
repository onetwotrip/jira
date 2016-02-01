require 'spec_helper'
describe 'JIRA::PullRequests' do
  describe 'valid?' do
    before :each do
      @pullrequests = JIRA::PullRequests.new [{ 'source' => {'url' => 'A'}},
                                              { 'source' => {'url' => 'B'}},
                                              { 'source' => {'url' => 'C'}}]
    end
    it 'should be valid' do
      expect(@pullrequests.valid?).to be true
    end
    it 'should not be valid' do
      @pullrequests.push Hash['source' => { 'url' => 'A' }]
      expect(@pullrequests.valid?).to_not be true
    end
    it 'should not be valid' do
      @pullrequests.push Hash['source' => { 'url2' => 'A' }]
      expect(@pullrequests.valid?).to_not be true
    end
    it 'should not be valid' do
      @pullrequests = JIRA::PullRequests.new
      expect(@pullrequests.valid?).to_not be true
      @pullrequests.push "String"
      expect(@pullrequests.valid?).to_not be true
    end
  end
end
