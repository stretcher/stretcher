require 'stretcher/search_results'
module Stretcher
  # Represents an Index context in elastic search.
  # Generally should be instantiated via Server#index(name).
  class Index < EsComponent
    attr_reader :server, :name, :logger

    def initialize(server, name, options={})
      @server = server
      @name = name
      @logger = options[:logger] || server.logger
    end

    # Returns a Stretcher::IndexType object for the type +name+.
    # Optionally takes a block, which will be passed a single arg with the Index obj
    # The block syntax returns the evaluated value of the block
    #
    #    my_index.index(:foo) # => #<Stretcher::Index ...>
    #    my_index.index(:foo) {|idx| 1+1} # => 2
    def type(name, &block)
      t = IndexType.new(self, name)
      block ? block.call(t) : t
    end

    # Given a hash of documents, will bulk index
    #
    #    docs = [{"_type" => "tweet", "_id" => 91011, "text" => "Bulked"}]
    #    server.index(:foo).bulk_index(docs)
    def bulk_index(documents, options={})
      body = documents.reduce("") {|post_data, d_raw|
        d = Hashie::Mash.new(d_raw)
        index_meta = { :_index => name, :_id => (d.delete(:id) || d.delete(:_id)) }
        
        d.keys.reduce(index_meta) do |memo, key|
          index_meta[key] = d.delete(key) if key.to_s.start_with?('_')
        end

        post_data << ({:index => index_meta}.to_json + "\n")
        post_data << (d.to_json + "\n")
      }
      @server.bulk body, options
    end

    # Given a hash of documents, will bulk delete
    #
    #    docs = [{"_type" => "tweet", "_id" => 91011}]
    #    server.index(:foo).bulk_delete(docs)
    def bulk_delete(documents)
      @server.bulk documents.reduce("") {|post_data, d_raw|
        d = Hashie::Mash.new(d_raw)
        action_meta = {"delete" => {"_index" => name, "_type" => d["_type"], "_id" => d["_id"] || d["id"]}}
        action_meta["delete"]["_parent"] = d["_parent"] if d["_parent"]
        post_data << (action_meta.to_json + "\n")
      }
    end

    # Creates the index, with the supplied hash as the optinos body (usually mappings: and settings:))
    def create(options={})
      request(:put, "/", {}, options)
    end

    # Deletes the index
    def delete
      request :delete
    end

    # Retrieves stats for this index
    def stats
      request :get, "_stats"
    end

    # Retrieves status for this index
    def status
      request :get, "_status"
    end

    # Retrieve the mapping for this index
    def get_mapping
      request :get, "_mapping"
    end

    # Retrieve settings for this index
    def get_settings
      request :get, "_settings"
    end

    # Check if the index has been created on the remote server
    def exists?
      # Unless the exception is hit we know its a 2xx response
      request(:head)
      true
    rescue Stretcher::RequestError::NotFound
      false
    end
    
    # Delete documents by a given query.
    # Per: http://www.elasticsearch.org/guide/reference/api/delete-by-query.html
    def delete_query(query)
      do_delete_query(query)
    end

    # Issues a search with the given query opts and body, both should be hashes
    #
    #    res = server.index('foo').search(size: 12, {query: {match_all: {}}})
    #    es.class   # Stretcher::SearchResults
    #    res.total   # => 1
    #    res.facets  # => nil
    #    res.results # => [#<Hashie::Mash _id="123" text="Hello">]
    #    res.raw     # => #<Hashie::Mash ...> Raw JSON from the search
    def search(generic_opts={}, explicit_body=nil)
      # Written this way to be more RDoc friendly
      do_search(generic_opts, explicit_body)
    end

    # Searches a list of queries against only this index
    # This deviates slightly from the official API in that *ONLY*
    # queries are requried, the empty {} preceding them are not
    # See: http://www.elasticsearch.org/guide/reference/api/multi-search.html
    #
    #    server.index(:foo).msearch([{query: {match_all: {}}}])
    #    # => Returns an array of Stretcher::SearchResults
    def msearch(queries=[])
      raise ArgumentError, "msearch takes an array!" unless queries.is_a?(Array)
      req_body = queries.reduce([]) {|acc,q|
        acc << {:index => name}
        acc << q
        acc
      }
      @server.msearch req_body
    end

    # Implements the Analyze API
    # EX:
    #    index.analyze("Candles", analyzer: :snowball)
    #    # => #<Hashie::Mash tokens=[#<Hashie::Mash end_offset=7 position=1 start_offset=0 token="candl" type="<ALPHANUM>">]>
    def analyze(text, analysis_params)
      request(:get, "_analyze", analysis_params) do |req|
        req.body = text
      end
    end

    # Perform a refresh making all items in this index available instantly
    def refresh
      do_refresh
    end

    # Full path to this index
    def path_uri(path="/")
      p = @server.path_uri("/#{name}")
      path ? p << "/#{path}" : p
    end
  end
end
