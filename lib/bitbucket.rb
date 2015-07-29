require 'addressable/uri'
require 'rest-client'

class BitBucket
  attr_reader :user, :owner, :repo, :password

  def initialize(opts)
    @user = opts[:user]
    @password = opts[:password]
    @owner = opts[:owner]
    @owner ||= opts[:user]
    @repo = opts[:repo]
    @connector = nil
  end

  def pull_requests(state = nil)
    path = 'pullrequests' + (state ? "?state=#{state}" : '')
    JSON.parse get_request path
  end

  def pull_request(number)
    JSON.parse get_request "pullrequests/#{number}"
  end

  def get_request(path)
    connector[path].get
  end

  def post_request(path, payload)
    connector[path].post payload
  end

  def put_request(path, payload)
    connector[path].put payload
  end

  def auth!(user = nil, password = nil)
    @user = user if user
    @password = password if password
    reconnect!
  end

  def repo=(repo)
    @repo = repo
    reconnect!
  end

  private

  def reconnect!
    @connector = nil
    connector
  end

  def connector
    return @connector if @connector
    @connector = RestClient::Resource.new "https://api.bitbucket.org/2.0/repositories/#{owner}/#{repo}/",
                                          user: @user,
                                          password: @password
  end
end
