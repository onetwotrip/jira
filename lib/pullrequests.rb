require 'git'

module JIRA
  ##
  # This class represent PullRequest
  class PullRequest
    GITATTR_REVIEWER_KEY = ENV.fetch('GITATTR_REVIEWER_KEY', 'reviewer.mail')
    attr_reader :pr, :repo

    def initialize(hash)
      begin
        valid?(hash)
      rescue => e
        puts e
        @pr = {}
        return false
      end
      @pr = hash
      # create_repodir
    end

    def src
      parse_url @pr['source']['url']
    end

    def dst
      parse_url @pr['destination']['url']
    end

    def changed_files
      @repo.gtree("origin/#{dst.branch}").diff('HEAD').stats[:files].keys
    end

    def reviewers
      changed_files.each do |file|
        @repo.get_attrs(file)[GITATTR_REVIEWER_KEY]
      end
    end

    def empty?
      @pr.empty?
    end

    private

    def parse_url(url)
      Git::Utils.url_to_ssh url
    end

    def valid?(input)
      src = parse_url(input['source']['url'])
      dst = parse_url(input['destination']['url'])
      fail 'Source and Destination repos in PR are different' unless src.to_repo_s == dst.to_repo_s
    end

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
  class PullRequests
    attr_reader :valid_msg
    attr_reader :prs

    def initialize(*arr)
      @prs = []
      arr.each do |pr|
        add(pr)
      end
    end

    def add(pr)
      if pr.instance_of?(PullRequest)
        @prs.push pr
      else
        fail TypeError, "Expected PullRequest value. Got #{pr.class}"
      end
    end

    def valid?
      !empty? && !duplicates?
    rescue => e
      @valid_msg = p(e)
      return false
    end

    def validate!
      fail @valid_msg unless valid?
    end

    def empty?
      fail 'Has no PullRequests' if @prs.empty?
    end

    def filter_by(key, *args)
      @prs.keep_if do |pr|
        args.include? key.split('_').inject(pr.pr) { |a, e| a[e] }
      end
      self
    end

    def grep_by(key, *args)
      self.class.new(
        *@prs.select do |pr|
          args.include? key.split('_').inject(pr.pr) { |a, e| a[e] }
        end
      )
    end

    def each
      @prs.each
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

    def duplicates?
      urls = @prs.map { |i| i.pr['source']['url'] }
      fail "PullRequests has duplication: #{urls.join ','}" if urls.uniq.length != urls.length
    end
  end
end
