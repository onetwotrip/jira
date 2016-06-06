require 'spec_helper'

describe Git::Base do
  it 'create pullrequests' do
    remote = double(:remote).as_null_object
    allow(Git::Remote).to receive(:new) { remote }
    allow_any_instance_of(Git::Base).to receive(:current_branch) { 'branch' }
    expect { described_class.new.create_pullrequest }.to raise_error URI::InvalidURIError
    allow(remote.url).to receive(:repo).and_return('vendor/repo')
    expect { described_class.new.create_pullrequest }.to raise_error RestClient::Unauthorized
  end
end
