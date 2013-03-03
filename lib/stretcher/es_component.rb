module Stretcher
  # Elasticsearch has symmetry across API endpoints for Server, Index, and Type, lets try and provide some common ground
  class EsComponent

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
      response = @server.request(:get, path_uri(uri_str)) do |req|
        req.body = body
      end
      SearchResults.new(:raw => response)      
    end
  end
end
