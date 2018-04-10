##
# This module represents Tests
module Ott
  ##
  # This class represents Tests
  class Test
    attr_reader :repo, :code, :dryrun, :outs, :name, :scope

    def initialize(repo:, name:, dryrun: nil, scope: 'release')
      @scope = scope
      @dryrun = dryrun
      @repo = repo
      @name = name
    end

    def status
      @dryrun ? true : code
    end

    def code # rubocop:disable Lint/DuplicateMethods
      @code ? @code.zero? : nil
    end

    def path
      @repo.dir.path
    end

    # :nocov:
    def run!
      @outs = ''
      @code = 0
      case @name
      when :npm
        @scope == 'release' ? npmfull : npmpart
      when :jscs
        jscs
      when :jshint
        jshint
      end
    end

    def npmfull
      @repo.chdir do
        t = Thread.new do
          @outs += `npm install && npm test 2>&1`
          @code += $?.exitstatus
        end
        t.join
      end
    end

    def npmpart
      @repo.chdir do
        t = Thread.new do
          @outs += `npm install && npm test 2>&1`
          @code += $?.exitstatus
        end
        t.join
      end
    end

    def jscs
      @repo.diff('origin/HEAD').each do |file|
        next unless File.extname(file.path) == '.js'
        ranges = Ott::Helpers.diffed_lines file.patch
        check_jscs file.path, ranges
      end
    end

    def jshint
      @repo.diff('origin/HEAD').each do |file|
        next unless File.extname(file.path) == '.js'
        ranges = Ott::Helpers.diffed_lines file.patch
        check_jshint file.path, ranges
      end
    end

    def check_jscs(filename, ranges = [])
      run_check "jscs -c '#{path}/.jscsrc' -r inline #{path}/#{filename}", filename, ranges if File.readable? path + '/.jscsrc'
    end

    def check_jshint(filename, ranges = [])
      run_check "jshint -c '#{path}/.jshintrc' #{path}/#{filename}", filename, ranges if File.readable? path + '/.jshintrc'
    end

    def run_check(command, filename = '', ranges = '')
      out, code = run_command(command)
      out.each_line do |line|
        if (l_text = format_line line, ranges)
          @outs += "#{filename}: line #{l_text}\n"
          @code += code.exitstatus
        end
      end
    end

    def format_line(line, ranges)
      return nil unless (md = /\.js: line (\d+)(,?.*)$/.match(line))
      return nil unless ranges.detect { |r| r.cover? md[1].to_i }
      "#{md[1]}#{md[2]}\n"
    end

    def run_command(command)
      raise ArgumentError.new, 'Empty or nil command!' if command.nil? || command.empty?
      Open3.capture2e(command)
    end
    # :nocov:
  end
end
