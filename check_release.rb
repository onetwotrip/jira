##
# frozen_string_literal: true
#
require 'simple_config'
require 'json'
require 'git'
require 'sendgrid-ruby'
require_relative 'lib/check'
require_relative 'lib/repo'

WORKDIR = SimpleConfig.git.workdir
BASEURL = ENV.fetch('BB_URL', 'git@bitbucket.org:')
EMAIL_FROM = SimpleConfig.sendgrid.from
SG_USER = SimpleConfig.sendgrid.user
SG_KEY = SimpleConfig.sendgrid.pass
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
).freeze
SKIPPED_EMAILS = %w(services@onetwotrip.com default@default.com)

if !ENV['payload'] || ENV['payload'].empty?
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

changes = payload['push']['changes'][0]
new_commit = changes['new']['target']['hash']
old_commit = changes.dig('old', 'target', 'hash') || 'master'

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
    m.to = SimpleConfig.git.reviewer
    m.from = EMAIL_FROM
    m.subject = "Изменены критичные файлы в #{payload['repository']['full_name']}"
    diff_link = 'https://bitbucket.org/'\
                "#{payload['repository']['full_name']}"\
                "/branches/compare/#{new_commit}..#{old_commit}#diff"
    m.html = <<MAIL
Привет, Строгий Контроль!<br />
Тут вот чего: <a href="mailto:#{email_to}">#{author_name}</a> взял и <a href="#{diff_link}">решил поменять</a>
кое-что критичное, а именно:<br />
<pre>#{crit_changed_files.join("\n")}</pre><br />
Подробности: <a href=\"https://bitbucket.org/#{payload['repository']['full_name']}/branches/compare/#{new_commit}..#{old_commit}\">тут</a>.
<br />Удачи!"
MAIL
  end
  SendGrid::Client.new(api_user: SG_USER, api_key: SG_KEY).send mail
end

exit 0 if res_text.empty?

print res_text
print "Will be emailed to #{email_to}\n"

mail = SendGrid::Mail.new do |m|
  m.to = email_to
  m.from = EMAIL_FROM
  m.subject = "JSCS/JSHint: проблемы с комитом в #{payload['repository']['full_name']}"
  msg = ''
  msg << "Привет <a href=\"mailto:#{email_to}\">#{author_name}</a>!<br />
Ты <a href=\"https://bitbucket.org/#{payload['repository']['full_name']}/commits/#{new_commit}\">коммитнул</a>,
 молодец.<br />"
  msg << "Только вот у тебя мастер не мержится в твою ветку.<br /><pre>#{merge_errors}</pre>" unless merge_errors.empty?
  msg << "А вот что имеют тебе сказать JSCS и JSHint:<pre>#{res_text}</pre>"
  m.html = msg
end

SendGrid::Client.new(api_user: SG_USER, api_key: SG_KEY).send mail
