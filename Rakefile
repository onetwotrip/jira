require "bundler/gem_tasks"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:test) do |t|
  t.pattern = Dir.glob('spec/**/*_spec.rb')
  # t.rcov = true
end
task :default => :test
