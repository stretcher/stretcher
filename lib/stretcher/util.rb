module Stretcher
  module Util
    def self.qurl(url, query_opts=nil)
      query_opts && !query_opts.empty? ? "#{url}?#{querify(query_opts)}" : url
    end
    
    def self.querify(hash)
      hash.map {|k,v| "#{k}=#{v}"}.join('&')
    end
  end
end
