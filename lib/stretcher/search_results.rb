require 'hashie/dash'
module Stretcher
  # Conveniently represents elastic search results in a more compact fashion
  #
  # Available properties:
  #
  # * raw : The raw response from elastic search
  # * total : The total number of matched docs
  # * facets : the facets hash
  # * results : The hit results with _id merged in to _source
  class SearchResults < Hashie::Dash
    property :raw, :required => true
    property :total
    property :facets
    property :results

    def initialize(*args)
      super
      self.total = raw.hits.total
      self.facets = raw.facets
      self.results = raw.hits.hits.collect {|r|
        (r.has_key?('_source') ? r['_source'] : r['fields']).merge({"_id" => r['_id']})
      }
    end
  end
end
