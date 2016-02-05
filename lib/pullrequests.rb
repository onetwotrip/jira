module JIRA
  ##
  # This class represents an array of PullRequests
  class PullRequests < Array
    attr_reader :valid_msg

    def valid?
      !empty? && items_valid? && !duplicates?
    rescue => e
      @valid_msg = e
      return false
    end

    def empty?
      fail 'Has no PullRequests' if super
    end

    private

    def items_valid?
      each do |item|
        if (!item.is_a? Hash) || (!item.dig('source', 'url'))
          fail "Item of PullRequests is not valid: #{item.inspect}"
        end
      end
    end

    def duplicates?
      urls = map { |i| i['source']['url'] }
      fail "PullRequests has duplication: #{urls.join ','}" if urls.uniq.length != urls.length
    end
  end
end
