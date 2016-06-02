##
# This module represents Ott methods
module Ott
  ##
  # This module represents helper methods
  module Helpers
    @root = Pathname.new(Dir.pwd)
    def self.root
      @root
    end

    # rubocop:disable Metrics/AbcSize
    def self.diffed_lines(diff)
      ranges = []
      diff.each_line do |l|
        return [] if l =~ /^Binary files ([^ ]+) and ([^ ]+) differ$/ # skip binary files
        return [0..1] if l =~ /@@ -0,0 +\d+ @@/                       # return [0..1] for a new file
        next unless (md = /^@@ -\d+(?:,\d+)? \+(\d+),(\d+) @@/.match(l))
        ranges << ((md[1].to_i)..(md[1].to_i + md[2].to_i))
      end
      puts "#{diff}\n Diff without marks or unknown marks!" if ranges.empty? && !diff.empty?
      ranges
    end
    # rubocop:enable Metrics/AbcSize
  end
end
