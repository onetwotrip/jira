require 'jira-ruby'
require 'jira/client'
require 'rest-client'
require 'addressable/uri'
require 'json'
require 'pullrequests'
require 'colorize'
require 'common/logger'
require 'common/bitbucket'

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
        LOGGER.info "Create Deployed link from #{key} to #{release_key}"
        li.save(params)
      end

      def branches
        related['branches'].map do |branch|
          begin
            repo(branch['url']).branch(branch['name'])
          rescue Tinybucket::Error::NotFound
            LOGGER.warn "Broken Link: branch #{branch['url']} not found"
            next
          end
        end.reject(&:nil?)
      end

      def api_pullrequests
        related['pullRequests'].map do |pullrequest|
          repo(pullrequest['url']).pull_request(pullrequest['id'][/\d+/])
        end
      end

      def repo(url)
        repo = Git::Utils.url_to_ssh url
        BITBUCKET.repo(repo.owner, repo.slug)
      end
      # :nocov:

      def rollback
        branches.each do |branch|
          if branch.name =~ /^#{SimpleConfig.jira.issue}-(pre|release-[0-9]{2}\.[0-9]{2}\.[0-9]{4})$/
            LOGGER.info "Rollback branch '#{branch.name}' from '#{branch.target['repository']['full_name']}'"
            branch.destroy
          end
        end
        api_pullrequests.each do |pr|
          if pr.state == 'OPEN'
            LOGGER.info "Decline pullrequest '#{pr.title}' from '#{pr.destination['repository']['full_name']}'"
            pr.decline
          end
        end
      end

      # rubocop:disable Style/PredicateName
      def has_transition?(name)
        # rubocop:disable Style/DoubleNegation
        !!get_transition_by_name(name)
      end
      # rubocop:enable Style/PredicateName, Style/DoubleNegation

      def get_transition_by_name(name)
        available_transitions = client.Transition.all(issue: self)
        @avail_transitions = []
        available_transitions.each do |transition|
          return transition if transition.name == name
          @avail_transitions << transition.name
        end
        LOGGER.warn "[#{key}] Transition state #{name} not found! Got only this: #{@avail_transitions.join(',')}"
      end

      def opts
        @opts ||= client.options
      end

      def transition(status)
        transition = get_transition_by_name status
        return unless transition
        LOGGER.info "#{key} changed status to #{transition.name}"
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

        unless @related['branches'].empty?
          @related['branches'].each do |branch|
            url = "https://bitbucket.org/OneTwoTrip/#{branch['repository']['name']}"
            branch['url'] = "#{url}/branch/#{branch['name']}"
            branch['createPullRequestUrl'] = "#{url}/pull-requests/new?source=#{branch['name']}"
            branch['repository']['url'] = url
          end
        end

        unless @related['pullRequests'].empty?
          @related['pullRequests'].each do |pr|
            repos_name = pr['url'][pr['url'].index('OneTwoTrip') + 11..pr['url'].index('/pull-requests') - 1]
            pr['source']['url'] = "https://bitbucket.org/OneTwoTrip/#{repos_name}/branch/#{pr['source']['branch']}"
            pr['destination']['url'] = "https://bitbucket.org/OneTwoTrip/#{repos_name}/branch/#{pr['destination']['branch']}"
          end
        end
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
            LOGGER.info "Issue #{key} skipped by filter"
            next
          end
          result.concat issue.dig_deployes(&filter).push(issue)
        end
        result
      end

      def all_deployes(&filter)
        if block_given? && !(yield self)
          LOGGER.info "Issue #{key} skipped by filter"
          return []
        end
        dig_deployes(&filter)
      end

      def all_labels
        release_labels = []
        linked_issues('deployes').each do |i|
          i.related['branches'].each do |branch|
            release_labels << branch['repository']['name'].to_s
          end
        end

        release_labels.uniq
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
