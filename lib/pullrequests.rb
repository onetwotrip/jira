module JIRA
  ##
  # This class represents an array of PullRequests
  class PullRequests < Array
    def valid?
      !empty? && items_valid? && !duplicates?
    end

    private

    def items_valid?
      each do |item|
        if (!item.is_a? Hash) || (!item.dig('source', 'url'))
          puts "Item of PullRequests is not valid: #{item.inspect}"
          return false
        end
      end
    end

    def duplicates?
      urls = map { |i| i['source']['url'] }
      urls.uniq.length != urls.length
    end
  end
end
