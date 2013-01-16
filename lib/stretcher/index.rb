require 'stretcher/search_results'
module Stretcher
  class Index
    attr_reader :server, :name, :logger
    
    def initialize(server, name, options={})
      @server = server
      @name = name
      @logger = options[:logger] || server.logger
    end

    def type(name)
      IndexType.new(self, name)
    end
    
    # Given a hash of documents, will bulk index
    def bulk_index(documents)
      @server.bulk documents.reduce("") {|post_data, d_raw|
        d = Hashie::Mash.new(d_raw)
        action_meta = {"index" => {"_index" => name, "_type" => d["_type"], "_id" => d["id"]}}
        action_meta["index"]["_parent"] = d["_parent"] if d["_parent"]
        post_data << (action_meta.to_json + "\n")
        post_data << (d.to_json + "\n")
      }
    end

    # Creates the index, with the supplied hash as the optinos body (usually mappings: and settings:))
    def create(options={})
      @server.request(:put, path_uri) do |req|
        req.body = options
      end
    end
    
    # Deletes the index
    def delete
      @server.request :delete, path_uri
    end

    # Retrieves stats from the server
    def stats
      @server.request :get, path_uri("/_stats")
    end
    
    # Retrieve the mapping from the server
    def mapping
      @server.request :get, path_uri("/_mapping")
    end
    
    # Check if the index has been created on the remote server
    def exists?
      @server.http.head(path_uri).status != 404
    end

    def search(query_opts={}, body=nil)
      uri = path_uri('/_search?' + Util.querify(query_opts))
      logger.info { "Stretcher Search: curl -XGET #{uri} -d '#{body.to_json}'" }
      response = @server.request(:get, uri) do |req|
        req.body = body
      end
      SearchResults.new raw: response
    end

    def path_uri(path="/")
      @server.path_uri("/#{name}") + path.to_s
    end
  end
end
