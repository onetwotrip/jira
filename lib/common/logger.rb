require 'logger'
require 'colorize'
STDOUT.sync = true

# :nocov:
class EnhancedLogger < Logger
  def initialize(logdev, shift_age = 10, shift_size = 1_048_576)
    super
    @history = Hash.new { |h, k| h[k] = [] }
    @colorize_dict = {
      'INFO' => 'green',
      'WARN' => '#f6c342',
      'ERROR' => '#f79232',
      'FATAL' => 'red',
    }
  end

  def add(severity, progname = nil, message = nil)
    super
    @history[format_severity(severity)].push message
  end

  def close
    super
    @history.close
  end

  def history_comment
    @history.reject { |k| k == 'INFO' }.map do |severity, msg|
      "#{severity}:\n{color:#{@colorize_dict[severity]}}#{msg.join("\n")}{color}"
    end.join("\n")
  end
end

LOGGER = EnhancedLogger.new(STDOUT)
LOGGER.formatter = proc do |severity, datetime, _progname, msg|
  date_format = datetime.strftime('%Y-%m-%d %H:%M:%S')
  if severity == 'INFO'
    "[#{date_format}] [#{severity}] #{msg}\n".green
  elsif severity =~ /WARN|ERROR/
    "[#{date_format}] [#{severity}] #{msg}\n".yellow
  elsif severity == 'FATAL'
    "[#{date_format}] [#{severity}] #{msg}\n".red
  else
    "[#{date_format}] [#{severity}] #{msg}\n"
  end
end
