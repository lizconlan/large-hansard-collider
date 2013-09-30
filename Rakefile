require 'rspec/core/rake_task'

namespace :spec do
  desc "Run tests with SimpleCov"
  RSpec::Core::RakeTask.new(:cov) do |t|
    ENV["COVERAGE"] = "1"
  end
end

RSpec::Core::RakeTask.new(:spec)

task :default => :spec