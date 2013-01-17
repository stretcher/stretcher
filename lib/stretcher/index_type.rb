module Stretcher
  # Represents an index  scoped to a specific type.
  # Generally should be instantiated via Index#type(name).
  class IndexType
    attr_reader :server, :index, :name, :logger
    
    def initialize(index, name, options={})
      @index = index
      @server = index.server
      @name = name
      @logger = options[:logger] || index.logger
    end

    # Retrieves the document by ID
    # Normally this returns the contents of _source, however, the 'raw' flag is passed in, it will return the full response hash
    def get(id, raw=false)
      res = server.request(:get, path_uri("/#{id}"))
      raw ? res : res["_source"]
    end
    
    # Index an item with a specific ID
    def put(id, source)
      server.request(:put, path_uri("/#{id}"), source)
    end
    
    # Uses the update api to modify a document with a script
    # To update a doc with ID 987 for example:
    # type.update(987, script: "ctx._source.message = 'Updated!'")
    # See http://www.elasticsearch.org/guide/reference/api/update.html
    def update(id, body)
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
    
    # Check if this index type is defined, if passed an id
    # this will check if the given document exists
    def exists?(id=nil)
      server.http.head(path_uri("/#{id}")).status != 404
    end

    def path_uri(path="/")
      index.path_uri("/#{name}") + path.to_s
    end
  end
end
