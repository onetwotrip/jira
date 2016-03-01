require 'git'
require 'erb'

module JIRA
  ##
  # This class represent PullRequest
  class PullRequest
    attr_reader :pr, :git_config, :changed_files, :reviewers

    def initialize(git_config, hash)
      fail ArgumentError, 'Missing git config' unless git_config
      begin
        valid?(hash)
      rescue => e
        puts e
        @pr = {}
        return false
      end
      @pr = hash
      @git_config = git_config
    end

    def empty?
      @pr.empty?
    end

    def src
      parse_url @pr['source']['url']
    end

    def dst
      parse_url @pr['destination']['url']
    end

    def authors
      @pr['author']['name']
    end

    def url
      @pr['url']
    end

    def name
      @pr['name']
    end

    def reviewers
      @reviewers ||= reviewers_by_files(changed_files)
    end

    def changed_files
      @changed_files ||= files
    end

    def send_notify
      yield ERB.new(File.read('views/review_mail.erb')).result(binding) unless reviewers.empty?
    end

    private

    def reviewers_by_files(files)
      files.map do |file|
        review_files(file)
      end.flatten.uniq
    end

    def files
      repo.gtree("origin/#{dst.branch}").diff('HEAD').stats[:files].keys.select do |file|
        review_files?(file)
      end
    end

    def review_files(file)
      if file == '.gitattributes'
        [@git_config[:reviewer]]
      else
        repo.get_attrs(file)[@git_config[:reviewer_key]]
      end
    end

    def review_files?(file)
      !review_files(file).empty?
    end

    def repo
      @repo ||= Git.get_branch dst.to_repo_s
      @repo.reset_hard "origin/#{dst.branch}"
      @repo.merge "origin/#{src.branch}"
      @repo
    end

    def parse_url(url)
      Git::Utils.url_to_ssh url
    end

    def valid?(input)
      src = parse_url(input['source']['url'])
      dst = parse_url(input['destination']['url'])
      fail 'Source and Destination repos in PR are different' unless src.to_repo_s == dst.to_repo_s
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

    def empty?
      fail 'Has no PullRequests' if @prs.empty?
    end

    def filter_by(key, *args)
      @prs.keep_if do |pr|
        value = key.split('_').inject(pr.pr) { |a, e| a[e] }
        args.any? { |word| value.include?(word) }
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
      @prs.each do |pr|
        yield pr
      end
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
