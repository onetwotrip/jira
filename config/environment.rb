#!/usr/bin/env ruby

# Module provides configuration
module Config
  DefaultConfig = Struct.new(:sendgrid, :jira, :git) do
    # Method should receive the config from yml
    # rubocop:disable MethodLength
    def initialize
      self.sendgrid = {
        from: ENV['SG_FROM'],
        user: ENV['SG_USER'],
        pass: ENV['SG_KEY'],
        to:   ENV['REVIEWER'],
        cc:   'dmitry.shmelev@default.com',
        subject: 'OTT-Infra: CodeReview' }
      self.jira = {
        username:     ENV['JIRA_USERNAME'],
        password:     ENV['JIRA_PASSWORD'],
        site:         ENV['JIRA_SITE'],
        issue:        ENV['ISSUE'],
        auth_type:    :basic,
        context_path: '' }
      self.git = {
        reviewer:     ENV['GITATTR_REVIEWER'],
        reviewer_key: ENV.fetch('GITATTR_REVIEWER_KEY', 'reviewer.mail'),
        workdir:      ENV.fetch('WORKDIR', '../repos/') }
    end
    # rubocop:enable all
  end

  def self.configure
    @config = DefaultConfig.new
    yield(@config) if block_given?
    @config
  end

  def self.config
    @config || configure
  end

  def self.method_missing(method, *args, &block)
    config.public_send(method) || super
  end
end
