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
      self.results = raw.hits.hits.collect do |r|
        k = ['_source', 'fields'].detect { |k| r.key?(k) }
        doc = k.nil? ? Hashie::Mash.new : r[k]
        if r.key?('highlight')
          doc.merge!({"_highlight" => r['highlight']})
        end
        doc.merge!({"_id" => r['_id'], "_index" => r['_index'], "_type" => r['_type'], "_score" => r['_score']})
      end
    end
  end
end
