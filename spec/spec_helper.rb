require 'coveralls'
Coveralls.wear!

require 'rspec'
require 'stretcher'

DEBUG_LOGGER = Logger.new('test_logs')
DEBUG_LOGGER.level = Logger::DEBUG
ES_URL = 'http://localhost:9200'
require File.expand_path(File.join(File.dirname(__FILE__), %w[.. lib stretcher]))
