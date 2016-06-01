require 'simple_config'
require 'jira'
require 'slop'
require 'colorize'
require './lib/issue'

opts = Slop.parse do |o|
  # Connection settings
  o.string '-u', '--username', 'username', default: SimpleConfig.jira.username
  o.string '-p', '--password', 'password', default: SimpleConfig.jira.password
  o.string '--site', 'site', default: SimpleConfig.jira.site
  o.string '--context_path', 'context path', default: ''
  o.string '--release', 'release', default: 'OTT-4487'

  o.bool '--dryrun', 'dont post comments to Jira', default: false

  o.on '--help', 'print the help' do
    puts o
    exit
  end
end

STDOUT.sync = true

options = { auth_type: :basic }.merge(opts.to_hash)
client = JIRA::Client.new(options)
release = client.Issue.find(opts[:release])
raise "WTF??? release search returned #{release.length} elements!" if (release.is_a? Array) && (release.length > 1)
release = release[0] if release.is_a? Array

pullrequests = release.pullrequests(SimpleConfig.git.to_h)
                      .filter_by_status('OPEN')
                      .filter_by_source_url(opts[:release])

unless pullrequests.valid?
  release.post_comment p("ReviewRelease: #{pullrequests.valid_msg}")
  exit
end

pullrequests.each do |pr|
  # Checkout repo
  puts "Clone/Open with #{pr.dst} branch #{pr.dst.branch} and merge #{pr.src.branch} and push".green
  begin
    pr.repo.push
  rescue Git::GitExecuteError => e
    puts e.message.red
    next
  end
end

release.deploys.each do |issue|
  puts issue.key
  # Transition to DONE
  issue.transition 'To master' if issue.get_transition_by_name 'To master'
end
