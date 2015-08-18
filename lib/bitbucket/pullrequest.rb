require 'rest-client'

class BitBucket
  class PullRequest
    def self.unimplemented
      fail 'Not Implemented!'
    end

    def self.from_jira(base, jira_pr)
      url_parts = jira_pr['url'].split('/')
      pr_num = url_parts[-1]
      repo = url_parts[-3]
      my_base = base.clone
      my_base.repo = repo
      res = my_base.get_request("pullrequests/#{pr_num}")
      hash = JSON.parse(res)
      new(my_base, hash)
    end

    def self.from_url(base, url)
      res = RestClient.get url, user: base.user, password: base.password
      hash = JSON.parse res
      new base, hash
    end

    attr_reader :base

    def initialize(base, hash)
      @base = base
      @hash = hash
    end

    def method_missing(*args)
      if args.length == 1 and hash.key? args[0].to_s
        hash[args[0].to_s]
      else
        super
      end
    end

    def to_hash
      @hash
    end

    def repo
      @base.repo
    end

    def reject!
      unimplemented
    end

    def merge!
      unimplemented
    end

    def open?
      @hash['state'] == 'OPEN'
    end

    def source_branch
      @hash['source']['branch']['name']
    end

    def dest_branch
      @hash['destination']['branch']['name']
    end

    def name
      @hash['title']
    end

    alias_method :title, :name
  end
end
