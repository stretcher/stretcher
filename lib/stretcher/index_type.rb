module Stretcher
  # Represents an index  scoped to a specific type.
  # Generally should be instantiated via Index#type(name).
  class IndexType < EsComponent
    attr_reader :server, :index, :name, :logger

    def initialize(index, name, options={})
      @index = index
      @server = index.server
      @name = name
      @logger = options[:logger] || index.logger
    end

    # Retrieves the document by ID.
    # Normally this returns the contents of _source, however, if the 'raw' flag is passed in, it will return the full response hash.
    # Returns nil if the document does not exist.
    # 
    # The :fields argument can either be a csv String or an Array. e.g. [:field1,'field2] or "field1,field2".
    # If the fields parameter is passed in those fields are returned instead of _source.
    #
    # If, you include _source as a field, along with other fields you MUST set the raw flag to true to 
    # receive both fields and _source. Otherwise, only _source will be returned
    def get(id, options={}, raw=false)
      if options == true || options == false # Support raw as second argument, legacy API
        raw = true
        options = {}
      end
      
      res = request(:get, id, options)
      raw ? res : (res["_source"] || res["fields"])
    end

    # Retrieves multiple documents of the index type by ID
    # http://www.elasticsearch.org/guide/reference/api/multi-get/
    def mget(ids, options={})
      request(:get, '_mget', options, :ids => ids)
    end

    def mget_existing(ids,options={})
      mget(ids, options)
    end

    # Explains a query for a specific document
    def explain(id, query, options={})
      request(:get, "#{id}/_explain", options, query)
    end

    # Index an item with a specific ID
    def put(id, source, options={})
      request(:put, id, options, source)
    end

    # Index an item with automatic ID generation
    def post(source, options={})
      request(:post, nil, options, source)
    end

    # Uses the update api to modify a document with a script
    # To update a doc with ID 987 for example:
    # type.update(987, script: "ctx._source.message = 'Updated!'")
    # See http://www.elasticsearch.org/guide/reference/api/update.html
    # Takes an optional, third options hash, allowing you to specify
    # Additional query parameters such as +fields+ and +routing+
    def update(id, body, options={})
      request(:post, "#{id}/_update", options, body)
    end

    # Deletes the document with the given ID
    def delete(id, options={})
      request :delete, id, options
    rescue Stretcher::RequestError => e
      raise e if e.http_response.status != 404
      false
    end

    # Takes a document and percolates it
    def percolate(document = {})
      request :get, '_percolate', nil, {:doc => document}
    end
    
    # Runs an MLT query based on the document's content.
    # This is actually a search, so a Stretcher::SearchResults object is returned
    #
    # Equivalent to hitting /index/type/id/_mlt
    # See http://www.elasticsearch.org/guide/reference/api/more-like-this/ for more
    # Takens an options hash as a second argument, for things like fields=
    def mlt(id, options={})
      SearchResults.new(request(:get, "#{id}/_mlt", options, nil, {}, :mashify => false))
    end

    # Retrieve the mapping for this type
    def get_mapping
      request :get, "_mapping"
    end

    # Delete the mapping for this type. Note this will delete
    # All documents of this type as well
    # http://www.elasticsearch.org/guide/reference/api/admin-indices-delete-mapping.html
    def delete_mapping
      request :delete, "_mapping"
    end

    # Alter the mapping for this type
    def put_mapping(body)
      request(:put, "_mapping", {}, body)
    end

    # Check if this index type is defined, if passed an id
    # this will check if the given document exists
    def exists?(id=nil)
      request :head, id
      true
    rescue Stretcher::RequestError::NotFound => e
      false
    end

    def delete_query(query)
      do_delete_query(query)
    end

    # Issues an Index#search scoped to this type
    # See Index#search for more details
    def search(generic_opts={}, explicit_body=nil)
      # Written this way to be more RDoc friendly
      do_search(generic_opts, explicit_body)
    end

    # Full path to this index type
    def path_uri(path=nil)
      p = index.path_uri(name)
      path ? p << "/#{path}" : p
    end
  end
end
