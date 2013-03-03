module Stretcher
  # Elasticsearch has symmetry across API endpoints for Server, Index, and Type, lets try and provide some common ground
  class EsComponent

    # Many of the methods marked protected are called by one line shims in subclasses. This is mostly to facilitate
    # better looking rdocs
    
    private
    
    def do_search(generic_opts={}, explicit_body=nil)
      uri_str = '/_search'
      body = nil
      if explicit_body
        uri_str << '?' + Util.querify(generic_opts)
        body = explicit_body
      else
        body = generic_opts
      end

      logger.info { "Stretcher Search: curl -XGET '#{uri_str}' -d '#{body.to_json}'" }
      response = request(:get, path_uri(uri_str)) do |req|
        req.body = body
      end
      SearchResults.new(:raw => response)      
    end

    def do_refresh
      request(:post, path_uri("/_refresh"))
    end

    def request(method, *args, &block)
      raise "Cannot issue request, no server specified!" unless @server
      @server.request(method, *args, &block)
    end
  end
end
