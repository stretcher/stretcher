module Stretcher
  module Util
    
    # cURL formats a Faraday req. Useful for logging
    def self.curl_format(req)
      body = "-d '#{req.body.is_a?(Hash) ? MultiJson.dump(req.body) : req.body}'" if req.body
      headers = req.headers.map {|name, value| "'-H #{name}: #{value}'" }.sort.join(' ')
      method = req.method.to_s.upcase
      url = Util.qurl(req.path,req.params)
      
      ["curl -X#{method}", "'" + url + "'", body, headers].compact.join(' ')  
    end

    # Formats a url + query opts
    def self.qurl(url, query_opts=nil)
      query_opts && !query_opts.empty? ? "#{url}?#{querify(query_opts)}" : url
    end

    def self.querify(hash)
      hash.map {|k,v| "#{k}=#{v}"}.join('&')
    end

    def self.clean_params params={}
      return unless params
      clean_params = {}
      params.each do |key, value|
        clean_params[key] = value.is_a?(Array) ? value.join(',') : value
      end
      clean_params
    end

  end
end
