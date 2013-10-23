module Stretcher
  # Elasticsearch has symmetry across API endpoints for Server, Index, and Type, lets try and provide some common ground
  class EsComponent

    # Many of the methods marked protected are called by one line shims in subclasses. This is mostly to facilitate
    # better looking rdocs

    def do_search(generic_opts={}, explicit_body=nil)
      query_opts = {}
      body = nil
      if explicit_body
        query_opts = generic_opts
        body = explicit_body
      else
        body = generic_opts
      end

      response = request(:get, "_search", query_opts, nil, {}, :mashify => false) do |req|
        req.body = body
      end
      SearchResults.new(response)
    end

    def do_refresh
      request(:post, "_refresh")
    end

    def request(method, path=nil, params={}, body=nil, headers={}, options={}, &block)
      prefixed_path = path_uri(path)
      raise "Cannot issue request, no server specified!" unless @server
      @server.request(method, prefixed_path, params, body, headers, options, &block)
    end

    def do_delete_query(query)
      request :delete, '_query' do |req|
        req.body = query
      end
    end

    def do_alias(alias_name_or_prefix)
      request(:get, "_alias/#{alias_name_or_prefix}")
    rescue Stretcher::RequestError::NotFound => e
      return {} if e.http_response.status == 404
      raise e
    end
  end
end
