require 'spec_helper'

describe Git::Base do
  it 'create pullrequests' do
    remote = double(:remote).as_null_object
    allow(Git::Remote).to receive(:new) { remote }
    allow_any_instance_of(Git::Base).to receive(:current_branch) { 'branch' }
    expect(described_class.new.create_pullrequest).to be_nil

    response = double(:resp_double)
    allow(response).to receive(:code) { 200 }
    allow(RestClient).to receive(:post) { response }
    allow(remote.url).to receive(:repo).and_return('vendor/repo')
    expect(described_class.new.create_pullrequest.code).to eq 200
  end
end
