require 'coveralls'
Coveralls.wear!

require 'rspec'
require 'stretcher'

File.open("test_logs", 'wb') {|f| f.write("")}
DEBUG_LOGGER = Logger.new('test_logs')
ES_URL = 'http://localhost:9200'
require File.expand_path(File.join(File.dirname(__FILE__), %w[.. lib stretcher]))

def ensure_test_index(server, name)
  i = server.index(name)
  begin
    i.delete
  rescue Stretcher::RequestError::NotFound
  end
  server.refresh
  i.create({
             :settings => {
               :number_of_shards => 1,
               :number_of_replicas => 0
             }
           })
  # Why do both? Doesn't hurt, and it fixes some races
  server.refresh
  i.refresh
  i
end
