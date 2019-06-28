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

  it 'delete branch - success' do
    remote = double(:remote).as_null_object
    response = double(:resp_double)
    branch = double(Tinybucket::Model::Branch, name: '-pre',
                    target: { 'repository' => { 'full_name' => 'owner/repo' } },
                    destroy: true,
                    repo_slug: 'Test',
                    repo_owner: 'god')
    allow(response).to receive(:code) { 200 }
    allow(Git::Remote).to receive(:new) { remote }
    allow_any_instance_of(Git::Base).to receive(:current_branch) { branch }
    allow(RestClient).to receive(:post) { response }
    allow(remote.url).to receive(:repo).and_return('vendor/repo')
    expect(described_class.new.delete_branch.code).to eq 200
  end

  it 'delete branch - error' do
    branch = double(Tinybucket::Model::Branch, name: '-pre',
                    target: { 'repository' => { 'full_name' => 'owner/repo' } },
                    destroy: true,
                    repo_slug: 'Test',
                    repo_owner: 'god')
    remote = double(:remote).as_null_object
    allow(Git::Remote).to receive(:new) { remote }
    allow_any_instance_of(Git::Base).to receive(:current_branch) { branch }
    expect(described_class.new.delete_branch).to raise_error(StandardError)
  end
end
