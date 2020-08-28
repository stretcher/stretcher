module Stretcher
  # Represents an index's docs.
  class IndexDocs < EsComponent
    attr_reader :server, :index, :logger

    def initialize(index, options = {})
      @index = index
      @server = index.server
      @logger = options[:logger] || index.logger
    end

    # Retrieves the document by ID.
    # Normally this returns the contents of _source, however, if the 'raw' flag is passed in, it will return the full response hash.
    # Returns nil if the document does not exist.
    #
    # The :stored_fields argument can either be a csv String or an Array. e.g. [:field1,'field2] or "field1,field2".
    # If the fields parameter is passed in those fields are returned instead of _source.
    #
    # If, you include _source as a field, along with other fields you MUST set the raw flag to true to
    # receive both fields and _source. Otherwise, only _source will be returned
    def get(id, params = {}, raw = false)
      if params == true || params == false # Support raw as second argument, legacy API
        raw = true
        params = {}
      end

      res = request(:get, "_doc/#{id}", params)
      raw ? res : (res["_source"] || res["fields"])
    end

    # Retrieves multiple documents of the index type by ID
    # http://www.elasticsearch.org/guide/reference/api/multi-get/
    def mget(ids, params = {})
      request(:get, '_doc/_mget', params, ids: ids)
    end

    # Explains a query for a specific document
    def explain(id, query, params = {})
      request(:get, "_doc/#{id}/_explain", params, query)
    end

    # Index an item with a specific ID
    def put(id, source, params = {})
      request(:put, "_doc/#{id}", params, source)
    end

    # Index an item with automatic ID generation
    def post(source, params = {})
      request(:post, '_doc', params, source)
    end

    # Uses the update api to modify a document with a script
    # To update a doc with ID 987 for example:
    # type.update(987, script: "ctx._source.message = 'Updated!'")
    # See http://www.elasticsearch.org/guide/reference/api/update.html
    # Takes an optional, third params hash, allowing you to specify
    # Additional query parameters such as +fields+ and +routing+
    def update(id, body, params = {})
      request(:post, "_update/#{id}", params, body)
    end

    # Deletes the document with the given ID
    def delete(id, params = {})
      request :delete, "_doc/#{id}", params
    rescue Stretcher::RequestError => e
      raise e if e.http_response.status != 404
      false
    end

    # Checks if a document exists.
    def exists?(id)
      request :head, "_doc/#{id}"
      true
    rescue Stretcher::RequestError::NotFound
      false
    end

    def delete_query(query, params = {})
      do_delete_query(query, params)
    end

    # Issues an Index#search scoped to this type
    # See Index#search for more details
    def search(generic_opts = {}, explicit_body = nil)
      # Written this way to be more RDoc friendly
      do_search(generic_opts, explicit_body)
    end

    # Full path to doc.
    def path_uri(path = nil)
      p = index.path_uri(nil)
      path ? p << "/#{path}" : p
    end

  end
end
