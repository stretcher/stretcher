module Stretcher
  module Util
    # cURL formats a Faraday req. Useful for logging
    def self.curl_format(http, req)
      headers = req.headers.map do |name,value|
        "-H '#{name}: #{value}'"
      end.join(' ')

      str = "curl -X#{req.method.to_s.upcase} '#{Util.qurl(http.url_prefix + req.path,req.params)}'  #{headers}"
      
      if req.body && !req.body.empty?
        body_clause = req.body.is_a?(String) ? req.body : req.body.to_json
        str << " -d '#{body_clause}'" 
      end

      str
    end
    
    # Formats a url + query opts
    def self.qurl(url, query_opts=nil)
      query_opts && !query_opts.empty? ? "#{url}?#{querify(query_opts)}" : url
    end

    def self.querify(hash)
      hash.map {|k,v| "#{k}=#{v}"}.join('&')
    end
  end
end
