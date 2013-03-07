module Stretcher
  # Raised when the underlying http status of an operation != 200
  class RequestError < StandardError
    attr_reader :http_response

    def initialize(http_response)
      @http_response = http_response
    end

    class NotFound < RequestError
    end
  end
end
