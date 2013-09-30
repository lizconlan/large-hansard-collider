if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter 'spec'
    add_group 'Lib', 'lib'
    add_group 'Models', 'models'
  end
end

RSpec.configure do |config|
  config.mock_framework = :mocha
end

ENV["RACK_ENV"] = "test" unless ENV["RACK_ENV"]

require 'rspec/autorun'
require "mocha/api"