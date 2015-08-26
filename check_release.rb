require 'json'
require 'git'
require 'sendgrid-ruby'
require_relative 'lib/check'
require_relative 'lib/repo'

WORKDIR = ENV.fetch('WORKDIR', '../repos/')
BASEURL = ENV.fetch('BB_URL', 'git@bitbucket.org:')
EMAIL_FROM = ENV.fetch('SG_FROM', 'default@default.com')
SG_USER = ENV.fetch('SG_USER', 'user')
SG_KEY = ENV.fetch('SG_KEY', 'pass')
NOTIFY_LIST = %w(
  src/mcore_modules/oauth2/**
  src/mcore_modules/session_auth/**
  src/mcore_modules/mcore/**
  src/mcore_modules/conf/api/**
  src/mcore_modules/payment/**
  src/mcore_modules/rapida/**
  src/mcore_modules/system/**
  src/mcore_modules/visitormanager/**
  src/tw_shared_types/payment/**
  src/tw_shared_types/payment_gate/**
  src/tw_shared_types/permissions/**
  src/tw_shared_types/pricing/**
  src/tw_shared_types/rapida/**
  src/tw_shared_types/virtual_cards/**
  src/tw_shared_types/virtual_wallet/**
  src/tw_shared_types/visitors/**
  src/mcore/**
  conf/api/**
  lib/nodejs/*
)
SKIPPED_EMAILS = %w(services@onetwotrip.com default@default.com)

if not ENV['payload'] or ENV['payload'].empty?
  print "No payload - no result\n"
  exit 2
end

payload = JSON.parse ENV['payload']

repo_name = payload['repository']['name']
print "Working with #{repo_name}\n"

# get latest
Dir.mkdir WORKDIR unless Dir.exist? WORKDIR

g_rep = GitRepo.new BASEURL + payload['repository']['full_name'], repo_name, workdir: WORKDIR

unless payload['push']['changes'][0]['new']
  puts 'Branch was deleted, nothing to do'
  exit 0
end

new_commit = payload['push']['changes'][0]['new']['target']['hash']
if payload['push']['changes'][0]['old']
  old_commit = payload['push']['changes'][0]['old']['target']['hash']
else
  # old_commit = g_rep.git.merge_base 'master', new_commit
  old_commit = 'master'
end

puts "Old: #{old_commit}; new: #{new_commit}"
author_name = g_rep.git.gcommit(new_commit).author.name
email_to = g_rep.git.gcommit(new_commit).author.email

exit 0 if SKIPPED_EMAILS.include? email_to # Bot commits skipped by Zubkov's request

res_text = ''
merge_errors = ''

g_rep.checkout new_commit
if old_commit == 'master'
  begin
    g_rep.merge! 'master'
  rescue Git::GitExecuteError => e
    merge_errors << "Failed to merge master to commit #{new_commit}.\nGit had this to say:\n#{e.message}\n\n"
    g_rep.abort_merge!
    g_rep.checkout new_commit
  end
end

res_text << g_rep.check_diff('HEAD', old_commit)

# SRV-735
crit_changed_files = []
g_rep.changed_files('HEAD', old_commit).each do |path|
  NOTIFY_LIST.each do |el|
    crit_changed_files << path if File.fnmatch? el, path
  end
end

crit_changed_files.uniq!

unless crit_changed_files.empty?
  puts "Notifying code-control!\n#{crit_changed_files.join "\n"}\n"
  mail = SendGrid::Mail.new do |m|
    m.to = 'vadzay@onetwotrip.com'
    m.from = EMAIL_FROM
    m.subject = "Изменены критичные файлы в #{payload['repository']['full_name']}"
    diff_link = 'https://bitbucket.org/'+
                "#{payload['repository']['full_name']}"+
                "/branches/compare/#{new_commit}..#{old_commit}#diff"
    m.html = <<MAIL
Привет, Строгий Контроль!<br />
Тут вот чего: <a href="mailto:#{email_to}">#{author_name}</a> взял и <a href="#{diff_link}">решил поменять</a>
кое-что критичное, а именно:<br />
<pre>#{crit_changed_files.join("\n")}</pre><br />
<br />Удачи!
MAIL
  end
  SendGrid::Client.new(api_user: SG_USER, api_key: SG_KEY).send mail
end

exit 0 if res_text.empty?

print res_text
print "Will be emailed to #{email_to}\n"

mail = SendGrid::Mail.new do |m|
  # m.to = email_to
  m.to = 'vadzay@onetwotrip.com'
  m.from = EMAIL_FROM
  m.subject = "JSCS/JSHint: проблемы с комитом в #{payload['repository']['full_name']}"
  m.html << "Привет <a href=\"mailto:#{email_to}\">#{author_name}</a>!<br />
Ты <a href=\"https://bitbucket.org/#{payload['repository']['full_name']}/commits/#{new_commit}\">коммитнул</a>,
 молодец.<br />"
  m.html << "Только вот у тебя мастер не мержится в твою ветку.<br /><pre>#{merge_errors}</pre>" unless merge_errors.empty?
  m.html << "А вот что имеют тебе сказать JSCS и JSHint:<pre>#{res_text}</pre>"
end

SendGrid::Client.new(api_user: SG_USER, api_key: SG_KEY).send mail
