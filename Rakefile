require 'bundler'
Bundler.setup

require 'active_record'
require 'rspec/core/rake_task'

Dir["tasks/*.rake"].sort.each { |ext| load ext }

namespace :spec do
  desc "Run tests with SimpleCov"
  RSpec::Core::RakeTask.new(:cov) do |t|
    ENV["COVERAGE"] = "1"
  end
end

RSpec::Core::RakeTask.new(:spec)

task :default => :spec