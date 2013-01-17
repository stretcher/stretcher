module Stretcher
  # Represents an index, but scoped to a specific type
  class IndexType
    attr_reader :server, :index, :name, :logger
    
    def initialize(index, name, options={})
      @index = index
      @server = index.server
      @name = name
      @logger = options[:logger] || index.logger
    end

    def get(id)
      server.request(:get, path_uri("/#{id}"))
    end

    def put(id, source)
      server.request(:put, path_uri("/#{id}"), source)
    end
    
    def update(update, body)
      server.request(:post, path_uri("/#{id}/_update"), body)
    end
    
    # Deletes the document with the given ID
    def delete(id)
      res = server.http.delete path_uri("/#{id}")
      
      # Since 404s are just not a problem here, let's simply return false
      if res.status == 404
        false
      elsif res.status >= 200 && res.status <= 299
        res.body
      else
        raise RequestError.new(res), "Error processing delete request! Status: #{res.status}\n Body: #{res.body}"
      end
    end

    # Retrieve the mapping for this type
    def get_mapping
      @server.request :get, path_uri("/_mapping")
    end
    
    # Delete the mapping for this type. Note this will delete
    # All documents of this type as well
    # http://www.elasticsearch.org/guide/reference/api/admin-indices-delete-mapping.html
    def delete_mapping
      @server.request :delete, path_uri("/_mapping")
    end

    # Alter the mapping for this type
    def put_mapping(body)
      @server.request(:put, path_uri("/_mapping")) {|req|
        req.body = body
      }
    end
    
    # Check if this index type is defined
    def exists?
      server.http.head(path_uri).status != 404
    end

    def path_uri(path="/")
      index.path_uri("/#{name}") + path.to_s
    end
  end
end
