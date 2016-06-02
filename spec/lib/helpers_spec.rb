require 'spec_helper'

describe Ott::Helpers do
  it 'check root' do
    expect(Ott::Helpers.root.class).to eq Pathname
    expect(Ott::Helpers.root.to_s).to eq Dir.pwd
  end

  it 'chef diffed_lines' do
    expect(Ott::Helpers.diffed_lines('').empty?).to eq true
    diff = <<-BODY
@@ -38,9 +38,7 @@ module Ott
@@ -58,23 +56,6 @@ module Ott
    BODY
    expect(Ott::Helpers.diffed_lines(diff)).to match_array [38..45, 56..62]
  end
end
