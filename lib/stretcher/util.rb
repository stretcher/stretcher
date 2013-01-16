module Stretcher
  module Util
    def self.querify(hash)
      hash.map {|k,v| "#{k}=#{v}"}.join('&')
    end
  end
end
