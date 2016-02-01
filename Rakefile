namespace :test do
  require 'bundler/gem_tasks'
  require 'rspec/core/rake_task'
  require 'rubocop/rake_task'

  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = Dir.glob('spec/**/*_spec.rb')
  end
  RuboCop::RakeTask.new(:rubocop)
end

task :test do
  %w(rubocop spec).each { |task| Rake::Task["test:#{task}"].invoke }
end
task default: 'test'
