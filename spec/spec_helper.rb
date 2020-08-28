require 'bundler/setup'
require 'coveralls'
Coveralls.wear!
require 'simplecov'
SimpleCov.start

require 'rspec'
require 'stretcher'
require 'its'
require 'pry'

File.open("test_logs", 'wb') {|f| f.write("")}
DEBUG_LOGGER = Logger.new('test_logs')
ES_URL = 'http://localhost:9200'
require File.expand_path(File.join(File.dirname(__FILE__), %w[.. lib stretcher]))

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = [:should, :expect] }
end

def ensure_test_index(server, name, mappings=nil)
  i = server.index(name)
  begin
    i.delete
  rescue Stretcher::RequestError::NotFound
  end
  server.refresh

  settings = {
      settings: {
          number_of_shards: 1,
          number_of_replicas: 0
      }
  }

  if mappings
    settings.merge!(mappings)
  end

  i.create(settings)
  # Why do both? Doesn't hurt, and it fixes some races
  server.refresh
  i.refresh
  
  attempts_left = 40
  
  # Sometimes the index isn't instantly available
  loop do
    idx_metadata = server.cluster.state[:metadata][:indices][i.name]
    i_state =  idx_metadata[:state]
    
    break if i_state == 'open'
    
    if attempts_left < 1
        raise "Bad index state! #{i_state}. Metadata: #{idx_metadata}" 
    end

    sleep 0.1
    attempts_left -= 1
  end
  
  i
end
