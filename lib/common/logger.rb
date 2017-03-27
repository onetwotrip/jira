require 'logger'
STDOUT.sync = true

# :nocov:
LOGGER = Logger.new(STDOUT)
LOGGER.formatter = proc do |severity, datetime, _progname, msg|
  date_format = datetime.strftime('%Y-%m-%d %H:%M:%S')
  if severity == 'INFO'
    "[#{date_format}] [#{severity}] #{msg}\n".green
  elsif severity == 'WARN'
    "[#{date_format}] [#{severity}] #{msg}\n".red
  else
    "[#{date_format}] [#{severity}] #{msg}\n"
  end
end
