require 'jira-ruby'
require 'jira/client'
require 'rest-client'
require 'addressable/uri'
require 'json'
require 'pullrequests'
require 'colorize'

module JIRA
  module Resource
    class Issue < JIRA::Base # :nodoc:
      # Link current issue to release_key
      # :nocov:
      def link(release_key)
        li = client.Issuelink.build
        params = {
          type: { name: 'Deployed' },
          inwardIssue: { key: release_key },
          outwardIssue: { key: key.to_s },
        }
        return if opts[:dryrun]
        puts "Create Deployed link from #{key} to #{release_key}".green
        li.save(params)
      end
      # :nocov:

      # rubocop:disable Style/PredicateName
      def has_transition?(name)
        # rubocop:disable Style/DoubleNegation
        !!get_transition_by_name(name)
      end
      # rubocop:enable Style/PredicateName, Style/DoubleNegation

      def get_transition_by_name(name)
        available_transitions = client.Transition.all(issue: self)
        available_transitions.each do |transition|
          return transition if transition.name == name
        end
        nil
      end

      def opts
        @opts ||= client.options
      end

      def transition(status)
        transition = get_transition_by_name status
        raise ArgumentError, "Transition state #{status} not found!" unless transition
        puts "#{key} changed status to #{transition.name}".green
        return if opts[:dryrun]
        action = transitions.build
        action.save!('transition' => { id: transition.id })
      end

      def post_comment(body)
        return if opts[:dryrun] || status.name == 'In Release'
        comment = comments.build
        comment.save(body: body)
      end

      def related
        params = {
          issueId: id,
          applicationType: 'bitbucket',
          dataType: 'pullrequest',
        }
        @related ||= JSON.parse(
          RestClient.get(create_endpoint('rest/dev-status/1.0/issue/detail').to_s, params: params)
        )['detail'].first
      end

      def create_endpoint(path)
        uri = "#{opts[:site]}#{opts[:context_path]}/#{path}"
        endpoint = Addressable::URI.parse(uri)
        endpoint.user = opts[:username]
        endpoint.password = opts[:password]
        endpoint
      end

      def pullrequests(git_config = nil)
        JIRA::PullRequests.new(
          *related['pullRequests'].map { |i| JIRA::PullRequest.new(git_config, i) }
        )
      end

      def linked_issues(param)
        client.Issue.jql(%(issue in linkedIssues(#{key},"#{param}")))
      end

      def search_deployes
        client.Issue.jql(
          %[(status in ("Merge ready")
          OR (status in ( "In Release") AND issue in linkedIssues(#{key},"deployes")))
          AND (Modes is Empty OR modes != "Manual Deploy")
          AND project not in (#{SimpleConfig.jira.excluded_projects.to_sql})
          ORDER BY priority DESC, issuekey DESC]
        )
      end

      def dig_deployes(&filter)
        result = []
        linked_issues('deployes').each do |issue|
          if block_given? && !(yield issue)
            puts "Issue #{key} skipped by filter".green
            next
          end
          result.concat issue.dig_deployes(&filter).push(issue)
        end
        result
      end

      def all_deployes(&filter)
        if block_given? && !(yield self)
          puts "Issue #{key} skipped by filter".green
          return []
        end
        dig_deployes(&filter)
      end

      def tags?(fkey, val)
        unless fields[fkey].nil?
          fields[fkey].each do |customfield|
            return true if customfield['value'] == val
          end
        end
        false
      end
    end
  end
end
