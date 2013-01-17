require 'logger'
require 'hashie'
require 'faraday'
require 'faraday_middleware'
require 'util'

module Stretcher
  class Server
    attr_reader :uri, :http, :logger

    def initialize(uri, options={})
      @uri = uri

      @http = Faraday.new(:url => @uri) do |builder|        
        builder.response :mashify
        builder.response :json, :content_type => /\bjson$/
        
        builder.request :json
        
        builder.adapter :net_http_persistent
        
        builder.options[:read_timeout] = 4
        builder.options[:open_timeout] = 2
      end
      
      if options[:logger]
        @logger = options[:logger]
      else
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::WARN
      end
      
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "[Stretcher][#{severity}]: #{msg}\n"
      end
    end

    def index(name)
      Index.new(self, name, logger: logger)
    end

    def bulk(data)
      request(:post, path_uri("/_bulk")) do |req|
        req.body = data
      end
    end
    
    # Returns true if the server is currently reachable, raises an error otherwise
    def up?
      request(:get, path_uri)
      true
    end

    def path_uri(path="/")
      @uri.to_s + path.to_s
    end
    
    # Handy way to query the server, returning *only* the body
    # Will raise an exception when the status is not in the 2xx range
    def request(method, *args, &block)
      logger.info("Stretcher: Issuing Request #{method}, #{args}")
      res = if block
              http.send(method, *args) do |req|
                # Elastic search does mostly deal with JSON
                req.headers["Content-Type"] = 'application/json'
                block.call(req)
               end
            else
              http.send(method, *args)
            end

      if res.status >= 200 && res.status <= 299
        res.body
      else
        err_str = "Error processing request (#{res.status})! #{res.env[:method]} URL: #{res.env[:url]}"
        err_str << "\n Resp Body: #{res.body}"
        raise RequestError.new(res), err_str
      end
    end
  end
end
