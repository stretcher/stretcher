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

    # Retrieves the document by ID
    # Normally this returns the contents of _source, however, the 'raw' flag is passed in, it will return the full response hash
    def get(id, raw=false)
      res = request(:get, id)
      raw ? res : res["_source"]
    end

    # Index an item with a specific ID
    def put(id, source)
      request(:put, id, source)
    end

    # Index an item with automatic ID generation
    def post(source)
      request(:post, nil, source)
    end

    # Uses the update api to modify a document with a script
    # To update a doc with ID 987 for example:
    # type.update(987, script: "ctx._source.message = 'Updated!'")
    # See http://www.elasticsearch.org/guide/reference/api/update.html
    def update(id, body)
      request(:post, "#{id}/_update", body)
    end

    # Deletes the document with the given ID
    def delete(id)
      request :delete, id
    rescue Stretcher::RequestError => e
      raise e if e.http_response.status != 404
      false
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
      request(:put, "_mapping") {|req|
        req.body = body
      }
    end

    # Check if this index type is defined, if passed an id
    # this will check if the given document exists
    def exists?(id=nil)
      request :head, id
      true
    rescue Stretcher::RequestError => e
      raise e if e.http_response.status != 404
      false
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
