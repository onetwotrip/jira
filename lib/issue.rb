require 'jira'
require 'jira/client'
require 'rest-client'
require 'addressable/uri'
require 'json'

module JIRA
  module Resource
    class Issue < JIRA::Base # :nodoc:
      def link
        endpoint = create_endpoint 'rest/api/2/issueLink'
        params = {
          type: { name: 'Deployed' },
          inwardIssue: { key: opts[:release].to_s },
          outwardIssue: { key: key.to_s },
        }
        return if opts[:dryrun]
        RestClient.post endpoint.to_s, params.to_json,
                        content_type: :json, accept: :json
      end

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
        fail ArgumentError, "Transition state #{status} not found!" unless transition
        puts "#{key} changed status to #{transition.name}"
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
        return @related if @related
        endpoint = create_endpoint 'rest/dev-status/1.0/issue/detail'
        params = {
          issueId: id,
          applicationType: 'bitbucket',
          dataType: 'pullrequest',
        }
        response = RestClient.get endpoint.to_s, params: params
        @related = JSON.parse(response)['detail'].first
        @related
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

      def deploys
        client.Issue.jql(%(issue in linkedIssues(#{key},"deployes")))
      end
    end
  end
end
