require 'pullrequest'

module JIRA
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
      raise TypeError, "Expected PullRequest value. Got #{pr.class}" unless pr.instance_of?(PullRequest)
      @prs.push pr
    end

    def valid?
      !empty? && !duplicates?
    rescue => e
      @valid_msg = p(e)
      return false
    end

    def empty?
      raise 'Has no PullRequests' if @prs.empty?
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

    def tests_fails
      names = []
      @prs.each do |pr|
        pr.tests.each do |test|
          names.push test.name unless test.code
        end
      end
      names
    end

    def tests_dryrun(name)
      @prs.each do |pr|
        pr.test(name).each do |test|
          return true if test.dryrun
        end
      end
      false
    end

    def tests_status(name = nil)
      @prs.each do |pr|
        pr.test(name).each do |test|
          return false unless test.status
        end
      end
      true
    end

    def tests_code(name)
      @prs.each do |pr|
        pr.test(name).each do |test|
          return false unless test.code
        end
      end
      true
    end

    def tests_status_string(task = nil)
      if tests_dryrun(task)
        tests_code(task) ? 'IGNORED (PASSED)' : 'IGNORED (FAIL)'
      else
        tests_status(task) ? 'PASSED' : 'FAIL'
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
      raise "PullRequests has duplication: #{urls.join ','}" if urls.uniq.length != urls.length
    end
  end
end
