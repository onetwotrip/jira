require 'git'

module JIRA
  ##
  # This class represent PullRequest
  class PullRequest < Hash
    GITATTR_REVIEWER_KEY = ENV.fetch('GITATTR_REVIEWER_KEY', 'reviewer.mail')
    attr_accessor :repo

    def initialize(hash)
      merge! hash
      create_repodir
    end

    def src
      Git::Utils.url_to_ssh self['source']['url']
    end

    def dst
      Git::Utils.url_to_ssh self['destination']['url']
    end

    def changed_files
      @repo.gtree("origin/#{dst.branch}").diff('HEAD').stats[:files].keys
    end

    def reviewers
      changed_files.each do |file|
        @repo.get_attrs(file)[GITATTR_REVIEWER_KEY]
      end
    end

    def valid?
      fail 'Source and Destination repos in PR are different' unless src.to_repo_s == dst.to_repo_s
    end

    private

    def create_repodir
      @repo = Git.get_branch dst.to_repo_s
      @repo.fetch
      @repo.merge "origin/#{src.branch}"
    end

    def clean_repodir
      @repo.reset_hard "origin/#{dst.branch}"
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

    def validate!
      fail @valid_msg unless valid?
    end

    def empty?
      fail 'Has no PullRequests' if super
    end

    def filter_by(key, *args)
      keep_if do |pr|
        args.include? key.split('_').inject(pr) { |a, e| a[e] }
      end
    end

    def grep_by(key, *args)
      self.class.new(
        select do |pr|
          args.include? key.split('_').inject(pr) { |a, e| a[e] }
        end
      )
    end

    def method_missing(m, *args, &block)
      if (key = m[/filter_by_(\w+)/, 1])
        filter_by(key, *args)
      elsif (key = m[/grep_by_(\w+)/, 1])
        grep_by(key, *args)
      else
        super
      end
    end

    private

    def items_valid?
      each(&:valid?)
    end

    def duplicates?
      urls = map { |i| i['source']['url'] }
      fail "PullRequests has duplication: #{urls.join ','}" if urls.uniq.length != urls.length
    end
  end
end
