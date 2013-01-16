require "bundler/gem_tasks"

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  ENV['COVERAGE'] = "1"
  t.rspec_opts = ['--color']
end
task :default => :spec