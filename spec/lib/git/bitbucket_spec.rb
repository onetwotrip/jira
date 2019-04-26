require 'spec_helper'

describe Git::Base do # rubocop:disable Metrics/BlockLength
  it 'create pullrequests - fail' do
    remote = double(:remote).as_null_object
    allow(Git::Remote).to receive(:new) { remote }
    allow_any_instance_of(Git::Base).to receive(:current_branch) { 'branch' }
    expect(described_class.new.create_pullrequest).to raise_error(StandardError)
  end
  it 'create pullrequests - success' do
    remote = double(:remote).as_null_object
    response = double(:resp_double)
    allow(response).to receive(:code) { 200 }
    allow(Git::Remote).to receive(:new) { remote }
    allow_any_instance_of(Git::Base).to receive(:current_branch) { 'branch' }
    allow(RestClient).to receive(:post) { response }
    allow(remote.url).to receive(:repo).and_return('vendor/repo')
    expect(described_class.new.create_pullrequest.code).to eq 200
  end

  it 'decline pullrequests - fail' do
    remote = double(:remote).as_null_object
    allow(Git::Remote).to receive(:new) { remote }
    allow_any_instance_of(Git::Base).to receive(:current_branch) { 'branch' }
    expect(described_class.new.decline_pullrequest).to raise_error(StandardError)
  end

  it 'decline pullrequests - success' do
    remote = double(:remote).as_null_object
    response = double(:resp_double)
    allow(response).to receive(:code) { 200 }
    allow(RestClient).to receive(:post) { response }
    allow(remote.url).to receive(:repo).and_return('vendor/repo')
    expect(described_class.new.decline_pullrequest).to eq 200
  end
end
