require 'open3'

def check_diff(g, new_commit, old_commit)
  res_text = ''
  prj_dir = Dir.new g.dir.path
  has_jscs = prj_dir.each.to_a.include? '.jscsrc'
  has_jshint = prj_dir.each.to_a.include? '.jshintrc'

  if not has_jscs and not has_jshint
    print "check_diff: Nothing to do.\n"
    return ''
  end
  print "Will use JSCS\n" if has_jscs
  print "Will use JSHint\n" if has_jshint

  diff = g.diff old_commit, new_commit

  if diff.to_a.empty?
    print "check_diff: Empty diff\n"
    return ''
  end

  current_commit = g.revparse 'HEAD'
  g.checkout new_commit unless current_commit == new_commit
  files_count = diff.each.to_a.length
  print "We have #{files_count} files to check\n"
  done_count = 0
  diff.each do |file|
    done_count += 1
    print "%.2f %% complete\r" % (done_count * 100.0 / files_count)
    next unless File.extname(file.path) == '.js'
    # Find changed lines
    ranges = []
    file.patch.each_line do |l|
      next unless (md = /^@@ -\d+,\d+ \+(\d+),(\d+) @@/.match(l))
      ranges << ((md[1].to_i)..(md[1].to_i + md[2].to_i))
    end
    # If file was deleted, we don't care about it.
    next if ranges.include? 0..0
    filename = file.path
    this_file_errors = ''
    if has_jscs
      # call jscs
      cmd = "jscs -c '#{prj_dir.to_path}/.jscsrc' #{prj_dir.to_path}/#{filename}"
      Open3.popen3(cmd) do |_stdin, stdout, _stderr|
        stdout.each_line do |line|
          next unless (md = /\.js: line (\d+)(,.*)$/.match(line))
          next unless ranges.detect { |r| r.cover? md[1].to_i }
          this_file_errors += "#{filename}: line #{md[1]}#{md[2]}\n"
        end
      end
    end
    if has_jshint
      # call jshint
      cmd = "jshint -c '#{prj_dir.to_path}/.jshintrc' #{prj_dir.to_path}/#{filename}"
      Open3.popen3(cmd) do |_stdin, stdout, _stderr|
        stdout.each_line do |line|
          next unless (md = /\.js: line (\d+)(,.*)$/.match(line))
          next unless ranges.detect { |r| r.cover? md[1].to_i }
          this_file_errors += "#{filename}: line #{md[1]}#{md[2]}\n"
        end
      end
    end
    res_text += "#{this_file_errors}\n" unless this_file_errors.empty?
  end
  g.checkout current_commit unless current_commit == new_commit
  res_text
end
