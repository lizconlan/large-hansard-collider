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

require 'active_record'
ENV["RACK_ENV"] = "test" unless ENV["RACK_ENV"]
begin
  test = ActiveRecord::Base.connection
rescue ActiveRecord::ConnectionNotEstablished
  ActiveRecord::Base.establish_connection(YAML::load(File.open('config/database.yml'))[ENV["RACK_ENV"]])
end

require 'rspec/autorun'
require "mocha/api"