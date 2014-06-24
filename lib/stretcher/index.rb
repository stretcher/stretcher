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

    # Returns a Stretcher::Alias object for the alias +name+.
    # Optionally takes a block, which will be passed a single arg with the Alias obj
    # The block syntax returns the evaluated value of the block
    #
    #   my_server.alias('user_1') # Stretcher::Alias
    #   my_server.alias { |alias| 1 } # 1
    def alias(name, &block)
      al = Alias.new(self, name, :logger => logger)
      block ? block.call(al) : al
    end

    # Given a hash of documents, will bulk index
    #
    #    docs = [{"_type" => "tweet", "_id" => 91011, "text" => "Bulked"}]
    #    server.index(:foo).bulk_index(docs)
    def bulk_index(documents, options={})
      bulk_action(:index, documents, options)
    end

    # Given a hash of documents, will bulk delete
    #
    #    docs = [{"_type" => "tweet", "_id" => 91011}]
    #    server.index(:foo).bulk_delete(docs)
    def bulk_delete(documents, options={})
      bulk_action(:delete, documents, options)
    end

    def bulk_action(action, documents, options={})
      action=action.to_sym
      
      body = documents.reduce("") {|post_data, d_raw|
        d = Hashie::Mash.new(d_raw)
        index_meta = { :_id => (d[:id] || d.delete(:_id)) }

        system_fields = %w{_type _parent _routing}
        d.keys.reduce(index_meta) do |memo, key|
          index_meta[key] = d.delete(key) if system_fields.include?(key.to_s)
        end

        post_data << (MultiJson.dump({action => index_meta}) << "\n")
        post_data << (MultiJson.dump(d) << "\n") unless action == :delete
        post_data
      }
      bulk body, options
    end

    # Creates the index, with the supplied hash as the options body (usually mappings: and settings:))
    def create(options=nil)
      request(:put, nil, nil, options)
    end

    # Deletes the index
    def delete
      request :delete
    end

    # Takes a collection of hashes of the form {:_type => 'foo', :_id => 123}
    # And issues an mget for them within the current index
    def mget(meta_docs)
      merge_data = {:_index => name}
      @server.mget(meta_docs.map {|d| d.merge(merge_data) })
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

    # Update settings for this index
    def update_settings(settings)
      request :put, "_settings", nil, settings
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

    # Perform an optimize on the index to merge and reduce the number of segments
    def optimize(options=nil)
      request(:post, "_optimize", options)
    end

    # Registers a percolate query against the index
    # http://www.elasticsearch.org/guide/reference/api/percolate/
    def register_percolator_query(query_name, options = {})
      server.request(:put, percolator_query_path(query_name), nil, options)
    end

    # Deletes a percolate query from the index
    # http://www.elasticsearch.org/guide/reference/api/percolate/
    def delete_percolator_query(query_name)
      server.request(:delete, percolator_query_path(query_name))
    end
    
    # Perform a raw bulk operation. You probably want to use Stretcher::Index#bulk_index
    # which properly formats a bulk index request.
    def bulk(data, options={})
      request(:post, "_bulk", options, data)
    end
    
    # Takes the name, text, and completion options to craft a completion query.
    # suggest("band_complete", "a", field: :suggest)
    # Use the new completion suggest API per http://www.elasticsearch.org/guide/reference/api/search/completion-suggest/
    def suggest(name, text, completion={})
      request(:post, "_suggest", nil, {name => {:text => text, :completion => completion}})
    end
    
    # Full path to this index
    def path_uri(path="/")
      p = @server.path_uri("/#{name}")
      path ? p << "/#{path}" : p
    end

    private

    def percolator_query_path(query_name)
      server.path_uri("/_percolator/#{name}/#{query_name}")
    end
  end
end
