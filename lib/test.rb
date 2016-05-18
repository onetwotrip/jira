##
# This module represents Tests
module Ott
  ##
  # This class represents Tests
  class Test
    attr_reader :repo, :code, :dryrun, :outs, :name

    def initialize(name, repo)
      @outs = ''
      @repo = repo
      @name = name
    end

    def status
      @dryrun ? true : code
    end

    def code
      @code ? @code.zero? : nil
    end

    def path
      @repo.dir.path
    end

    # :nocov:
    def run!(params = {})
      @code = 0
      case @name
      when :npm
        npmrun(params)
      when :js
        jsrun(params)
      end
    end

    def npmrun(params = {})
      @repo.chdir do
        t = Thread.new do
          @outs = `npm install 2>&1`
          @code = $?.exitstatus # rubocop:disable Style/SpecialGlobalVars
          @outs += `npm test 2>&1`
          @code += $?.exitstatus # rubocop:disable Style/SpecialGlobalVars
          @dryrun = true if params[:dryrun]
        end
        t.join
      end
    end

    def jsrun(params = {})
      @repo.diff('origin/HEAD').each do |file|
        next unless File.extname(file.path) == '.js'
        ranges = diffed_lines file.patch
        check_jscs file.path, ranges
        check_jshint file.path, ranges
      end
      @dryrun = 1 if params[:dryrun]
    end

    # rubocop:disable Metrics/AbcSize
    def diffed_lines(diff)
      ranges = []
      diff.each_line do |l|
        return [] if l =~ /^Binary files ([^ ]+) and ([^ ]+) differ$/ # skip binary files
        return [0..1] if l =~ /@@ -0,0 +\d+ @@/                       # return [0..1] for a new file
        next unless (md = /^@@ -\d+(?:,\d+)? \+(\d+),(\d+) @@/.match(l))
        ranges << ((md[1].to_i)..(md[1].to_i + md[2].to_i))
      end
      if ranges.empty? && !diff.empty?
        puts diff
        puts 'Diff without marks or unknown marks!'
      end
      ranges
    end
    # rubocop:enable Metrics/AbcSize

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
      if command.nil? || command.empty?
        raise ArgumentError.new, 'Empty or nil command!'
      end
      Open3.capture2e(command)
    end
    # :nocov:
  end
end
