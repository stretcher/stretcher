require 'hashie/dash'
module Stretcher
  class SearchResults < Hashie::Dash
    property :raw, required: true
    property :total
    property :facets
    property :results
    
    def initialize(*args)
      super
      self.total = raw.hits.total
      self.facets = raw.facets
      self.results = raw.hits.hits.collect { |r| r['_source'] }
    end
  end
end