require 'git'

module JIRA
  ##
  # This class represent PullRequest
  class PullRequest < Hash
    def src
      Git::Utils.url_to_ssh self['source']['url']
    end

    def dst
      Git::Utils.url_to_ssh self['destination']['url']
    end
  end

  ##
  # This class represents an array of PullRequests
  class PullRequests < Array
    attr_reader :valid_msg

    def initialize(arr)
      arr.each do |i|
        add(i)
      end
    end

    def add(pr)
      push PullRequest.new.merge(pr)
    end

    def valid?
      !empty? && items_valid? && !duplicates?
    rescue => e
      @valid_msg = e
      return false
    end

    def empty?
      fail 'Has no PullRequests' if super
    end

    def filter_by(key, *args)
      self.class.new(
        select do |pr|
          args.include? key.split('_').inject(pr) { |a, e| a[e] }
        end
      )
    end

    def method_missing(m, *args, &block)
      if (key = m[/filter_by_(\w+)/, 1])
        filter_by(key, *args)
      else
        super
      end
    end

    private

    def items_valid?
      each do |item|
        if item.src.to_repo_s != item.dst.to_repo_s
          fail 'Source and Destination repos in PR are different'
        end
      end
    end

    def duplicates?
      urls = map { |i| i['source']['url'] }
      fail "PullRequests has duplication: #{urls.join ','}" if urls.uniq.length != urls.length
    end
  end
end
