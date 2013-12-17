require 'bundler'
Bundler.setup

require 'active_record'
require 'rake'
require 'rspec/core/rake_task'

Dir["./tasks/*.rake"].sort.each { |ext| load ext }

namespace :spec do
  task :prepare do
    ENV["RACK_ENV"] = "test"
    Rake::Task["db:drop"].invoke
    Rake::Task["db:create"].invoke
    Rake::Task["db:migrate"].invoke
  end
  
  desc "Run tests with SimpleCov"
  RSpec::Core::RakeTask.new(:cov) do |t|
    Rake::Task["spec:prepare"].invoke
    ENV["COVERAGE"] = "1"
  end
end

RSpec::Core::RakeTask.new(:spec) do |t|
  Rake::Task["spec:prepare"].invoke
end

task :default => :spec