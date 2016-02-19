require 'jira'
require 'issue'
require 'pullrequests'
require 'ottinfra/sendmail'
require 'erb'
##
# This class represent CodeReview procedure
class CodeReview
  attr_reader :jira, :issue, :pullrequests, :workdir

  def initialize(&block)
    @pullrequests = JIRA::PullRequests.new
    begin
      instance_eval(&block)
      # valid_pullrequests
      #  send_review
    rescue => e
      puts e
    end
  end

  def workdir(val)
    @workdir = val || '../repos/'
  end

  def jira(args = {})
    @jira = JIRA::Client.new username: args[:user],
                             password: args[:pass],
                             site: args[:site],
                             auth_type: :basic,
                             context_path: ''
  end

  def issue(val)
    fail 'CodeReview: No issue - no cry!' unless val
    @issue = @jira.Issue.find(val)
  end

  def pullrequests
    puts @issue.get_pullrequests.inspect
  end

  def valid_pullrequests
    @issue.post_comment p("CodeReview: #{@pullrequests.valid_msg}") unless @pullrequests.valid?
  end

  def reviewers
    @pullrequests.each do |pr|
      # Clone/Open dist branch
      repo = Git.get_branch dst.to_repo_s
      repo.fetch
      # Merge src to dist branch
      repo.merge "origin/#{src.branch}"
      # Get files change
      repo.gtree("origin/#{dst.branch}").diff('HEAD').stats[:files].keys.each do |file|
        # Set change flag if .gitattributes file modified
        cr[:gitattr_flag] = true if file.include? '.gitattributes'
        # Get reviewer mail by file
        repo.get_attrs(file)[GITATTR_REVIEWER_KEY].each do |reviewer|
          cr[:changes] << file
          cr[:reviewers] << reviewer
        end
      end
      # Cleanup local repo
      repo.reset_hard "origin/#{dst.branch}"
      cr[:authors] << pr['author']['name']
      cr[:pullrequests] << Hash[url: pr['url'], name: pr['name']]
    end
  end

  def send_review
    mailer = OttInfra::SendMail.new(user: SENDGRID_USER,
                                    pass: SENDGRID_PASS)

    if cr[:gitattr_flag]
      mailer.add from: SENDGRID_FROM,
                 to: GITATTR_REVIEWER,
                 cc: 'dmitry.shmelev@default.com',
                 subject: 'CodeReview: GitAttribute changed!',
                 message: ERB.new(File.read('views/gitattr_mail.erb')).result
    end
    unless cr[:reviewers].empty?
      mailer.add from: SENDGRID_FROM,
                 to: cr[:reviewers],
                 cc: 'dmitry.shmelev@default.com',
                 subject: 'CodeReview',
                 message: ERB.new(File.read('views/review_mail.erb')).result
    end

    # Send CodeReview
    if mailer.mails.empty?
      puts 'CodeReview: No changes for review'
    else
      mailer.sendmail
    end
  end
end
