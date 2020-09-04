require 'helpers'
require 'test'
require 'git'
require 'erb'
require 'uri'

module JIRA
  ##
  # This class represent PullRequest
  class PullRequest
    attr_reader :pr, :git_config, :changed_files, :reviewers, :tests

    def initialize(git_config, hash)
      raise ArgumentError, 'Missing git config' unless git_config

      begin
        valid?(hash)
      rescue StandardError => e
        puts e
        @pr = {}
        return false
      end

      @pr = hash
      @tests = []
      @git_config = git_config
    end

    def run_tests(params = {})
      test = Ott::Test.new params.merge(repo: @repo)
      test.run!
      @tests.push test
    end

    def tests_fails
      @tests.reject(&:status)
    end

    def test(name)
      name ? @tests.select { |t| t.name == name } : @tests
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

    def reviewers # rubocop:disable Lint/DuplicateMethods
      @reviewers ||= reviewers_by_files(changed_files)
    end

    def changed_files # rubocop:disable Lint/DuplicateMethods
      @changed_files ||= files
    end

    def repo
      LOGGER.info "Get repo for #{dst.full_url}"
      @repo ||= Git.get_branch URI.decode_www_form_component(dst.full_url)
      LOGGER.info "Git fetching"
      @repo.chdir do
        `git fetch --prune`
      end
      LOGGER.info "Git merging"
      @repo.merge("origin/#{@pr['source']['branch']}", "merge #{@pr['source']['branch']} into #{@pr['destination']['branch']}")
      @repo
    end

    # use it when you need just repo owner and repo name parameters for BB request
    def simple_repo
      @repo ||= Git.get_branch URI.decode_www_form_component(dst.full_url)
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

    def parse_url(url)
      Git::Utils.url_to_ssh url
    end

    def valid?(input)
      src = parse_url(input['source']['url'])
      dst = parse_url(input['destination']['url'])
      raise 'Source and Destination repos in PR are different' unless src.to_s == dst.to_s
    end
  end
end
