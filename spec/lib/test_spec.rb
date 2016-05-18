require 'spec_helper'
describe Ott::Test do
  before :each do
    @repo_double = double(:repo_double)
    @tests = described_class.new(:task, @repo_double)
  end

  describe '.dryrun?' do
    it 'on init' do
      expect(@tests.dryrun).to eq nil
    end
  end
  describe '.status?' do
    it 'on init' do
      expect(@tests.status).to eq nil
    end
    it 'on fail' do
      @tests.instance_eval { @code = 1 }
      expect(@tests.status).to eq false
    end
    it 'on ok' do
      @tests.instance_eval { @code = 0 }
      expect(@tests.status).to eq true
    end
    it 'with dryrun' do
      @tests.instance_eval { @dryrun = 1 }
      @tests.instance_eval { @code = 1 }
      expect(@tests.status).to eq true
    end
  end
  describe '.outs' do
    it 'on init' do
      expect(@tests.outs).to eq ''
    end
  end
  it '.path returns repo.path' do
    @dir_double = double(:dir_double)
    allow(@repo_double).to receive(:dir) { @dir_double }
    allow(@dir_double).to receive(:path) { 'path_to_repo' }
    expect(@tests.path).to eq 'path_to_repo'
  end
end
