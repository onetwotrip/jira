require 'jira/client'
require 'rest-client'
require 'addressable/uri'
require 'json'

module JIRA
  module Resource
    class Issue < JIRA::Base # :nodoc:
      attr_reader :opts
      attr_writer :opts

      def link
        endpoint = create_endpoint 'rest/api/2/issueLink'
        params = {
          type: { name: 'Deployed' },
          inwardIssue: { key: "#{opts[:release]}" },
          outwardIssue: { key: "#{key}" }
        }
        return if opts[:dryrun]
        RestClient.post endpoint.to_s, params.to_json,
                        content_type: :json, accept: :json
      end

      def get_transition_by_name(name)
        available_transitions = client.Transition.all(issue: self)
        available_transitions.each do |transition|
          return transition if transition.name == name
        end
        nil
      end

      def opts_setter(options)
        @opts = options
      end

      def transition(status)
        transition = get_transition_by_name status
        return unless transition
        puts transition.name
        return if opts[:dryrun]
        action = transitions.build
        action.save!('transition' => { id: transition.id })
      end

      def post_comment(body)
        return if opts[:dryrun] || status == 'In Release'
        comment = comments.build
        comment.save(body: body)
      end

      def related
        endpoint = create_endpoint 'rest/dev-status/1.0/issue/detail'
        params = {
          issueId: id,
          applicationType: 'bitbucket',
          dataType: 'pullrequest'
        }
        response = RestClient.get endpoint.to_s, params: params
        related = JSON.parse(response)['detail']
        related
      end

      def create_endpoint(path)
        uri = "#{opts[:site]}#{opts[:contextpath]}/#{path}"
        endpoint = Addressable::URI.parse(uri)
        endpoint.user = opts[:username]
        endpoint.password = opts[:password]
        endpoint
      end

      def deploys
        client.Issue.jql(%(issue in linkedIssues(#{key},"deployes")))
      end
    end
  end
end
