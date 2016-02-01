module JIRA
  class PullRequests < Array
    def valid?
      if self.empty?
        puts "PullRequests is empty"; return
      end
      self.each do |item|
        unless item.is_a? Hash
          puts "Item is not Hash"; return
        end
        unless item['source'] && item['source']['url']
          puts "Item has not ['source']['url'] key"; return
        end
      end
      urls = self.map{|i| i['source']['url']}
      if urls.uniq.length != urls.length
        puts "PullRequests has duplicates"; return
      end
      true
    end
  end
end
