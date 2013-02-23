module Stretcher
  class Server
    attr_reader :uri, :http, :logger

    # Instantiate a new instance in a manner convenient for using the block syntax.
    # Can be used interchangably with +Stretcher::Server.new+ but will return the value
    # of the block if present. See the regular constructor for full options.
    def self.with_server(*args)
      s = self.new(*args)
      yield s
    end
    
    # Represents a Server context in elastic search.
    # Use +with_server+ when you want to use the block syntax.
    # The options hash takes an optional instance of Logger under :logger.
    #
    #    server = Stretcher::Server.new('http://localhost:9200')
    def initialize(uri='http://localhost:9200', options={})
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

    # Returns a Stretcher::Index object for the index +name+.
    # Optionally takes a block, which will be passed a single arg with the Index obj
    # The block syntax returns the evaluated value of the block
    # 
    #    my_server.index(:foo) # => #<Stretcher::Index ...>
    #    my_server.index(:foo) {|idx| 1+1} # => 2
    def index(name, &block)
      idx = Index.new(self, name, logger: logger)
      block ? block.call(idx) : idx
    end

    def bulk(data)
      request(:post, path_uri("/_bulk")) do |req|
        req.body = data
      end
    end

    # Retrieves stats for this server
    def stats
      request :get, path_uri("/_stats")
    end

    # Retrieves status for this server
    def status
      request :get, path_uri("/_status")
    end
    
    # Returns true if the server is currently reachable, raises an error otherwise
    def up?
      request(:get, path_uri)
      true
    end
    
    # Takes an array of msearch data as per
    # http://www.elasticsearch.org/guide/reference/api/multi-search.html
    # Should look something like:
    #    data = [
    #      {"index" : "test"}
    #      {"query" : {"match_all" : {}}, "from" : 0, "size" : 10}
    #      {"index" : "test", "search_type" : "count"}
    #      {"query" : {"match_all" : {}}}
    #    ]
    #    server.msearch(data)
    def msearch(body=[])
      raise ArgumentError, "msearch takes an array!" unless body.is_a?(Array)
      fmt_body = body.map(&:to_json).join("\n") + "\n"
      logger.info { "Stretcher msearch: curl -XGET #{uri} -d '#{fmt_body}'" }
      res = request(:get, path_uri("/_msearch")) {|req|
        req.body = fmt_body
      }
      
      errors = res.responses.select {|r| r[:error]}.map(&:error)
      if !errors.empty?
        raise RequestError.new(res), "Could not msearch #{errors.inspect}" 
      end
      
      res['responses'].map {|r| SearchResults.new(raw: r)}
    end

    # Retrieves multiple documents, possibly from multiple indexes
    # as per: http://www.elasticsearch.org/guide/reference/api/multi-get.html
    def mget(body={})
      request(:get, path_uri("/_mget")) {|req|
        req.body = body
      }
    end
    
    # Implements the Analyze API
    # EX: 
    #    server.analyze("Candles", analyzer: :snowball)
    #    # => #<Hashie::Mash tokens=[#<Hashie::Mash end_offset=7 position=1 start_offset=0 token="candl" type="<ALPHANUM>">]>
    # as per: http://www.elasticsearch.org/guide/reference/api/admin-indices-analyze.html
    def analyze(text, analysis_params)
      request(:get, path_uri("/_analyze"), analysis_params) do |req|
        req.body = text
      end
    end

    # Full path to the server root dir
    def path_uri(path="/")
      @uri.to_s + path.to_s
    end

    # Handy way to query the server, returning *only* the body
    # Will raise an exception when the status is not in the 2xx range
    def request(method, *args, &block)
      logger.info { "Stretcher: Issuing Request #{method.upcase}, #{args}" }
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
