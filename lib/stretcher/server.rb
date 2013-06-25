module Stretcher
  class Server < EsComponent
    attr_reader :uri, :http, :logger

    # Internal use only.
    # Returns a properly configured HTTP client when initializing an instance
    def self.build_client(uri, options={})
      http = Faraday.new(:url => uri) do |builder|
        builder.response :mashify
        builder.response :json, :content_type => /\bjson$/

        builder.request :json

        builder.options[:read_timeout] = options[:read_timeout] || 4
        builder.options[:open_timeout] = options[:open_timeout] || 2

        if faraday_configurator = options[:faraday_configurator]
          faraday_configurator.call(builder)
        else
          builder.adapter :excon
        end
      end
      http.headers = {
        :accept =>  'application/json',
        :user_agent => "Stretcher Ruby Gem #{Stretcher::VERSION}",
        "Content-Type" => "application/json"
      }

      uri_components = URI.parse(uri)
      if uri_components.user || uri_components.password
        http.basic_auth(uri_components.user, uri_components.password)
      end

      http
    end

    # Internal use only.
    # Builds a logger when initializing an instance
    def self.build_logger(options)
      logger = options[:logger] || Logger.new(STDOUT)
      log_level = options[:log_level] || :warn
      logger.level = Logger.const_get(log_level.to_s.upcase)

      # We don't want to override the formatter if an external logger is used
      unless options[:logger]
        logger.formatter = proc do |severity, datetime, progname, msg|
          "[Stretcher][#{severity}]: #{msg}\n"
        end
      end
      
      logger
    end

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
    #
    # The default implementation here uses the net_http_persistent adapter
    # for faraday. If you would like to use a different HTTP library, or alter
    # other faraday config settings you may specify an optional :faraday_configurator
    # argument, with a Proc as a value. This will be called once with the faraday builder.
    #
    # For instance:
    # configurator = proc {|builder| builder.adapter :typhoeus
    # Stretcher::Server.new('http://localhost:9200', :faraday_configurator => configurator)
    def initialize(uri='http://localhost:9200', options={})
      @request_mtx = Mutex.new
      @uri = uri
      @http = self.class.build_client(@uri, options)
      @logger = self.class.build_logger(options)
    end

    # Returns a Stretcher::Index object for the index +name+.
    # Optionally takes a block, which will be passed a single arg with the Index obj
    # The block syntax returns the evaluated value of the block
    #
    #    my_server.index(:foo) # => #<Stretcher::Index ...>
    #    my_server.index(:foo) {|idx| 1+1} # => 2
    def index(name, &block)
      idx = Index.new(self, name, :logger => logger)
      block ? block.call(idx) : idx
    end

    # Perform a raw bulk operation. You probably want to use Stretcher::Index#bulk_index
    # which properly formats a bulk index request.
    def bulk(data, options={})
      request(:post, path_uri("/_bulk"), options, data)
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

      res = request(:get, path_uri("/_msearch"), {}, fmt_body)

      errors = res.responses.map(&:error).compact
      if !errors.empty?
        raise RequestError.new(res), "Could not msearch #{errors.inspect}"
      end

      res['responses'].map {|r| SearchResults.new(:raw => r)}
    end

    # Retrieves multiple documents, possibly from multiple indexes
    # Takes an array of docs, returns an array of docs
    # as per: http://www.elasticsearch.org/guide/reference/api/multi-get.html
    # If you pass :exists => true as the second argument it will not return stubs
    # for missing documents. :exists => false works in reverse
    def mget(docs=[], arg_opts={})
      #Legacy API
      return legacy_mget(docs) if docs.is_a?(Hash)
      
      opts = {:exists => true}.merge(arg_opts)
      
      res = request(:get, path_uri("/_mget"), {}, {:docs => docs})[:docs]
      if opts.has_key?(:exists)
        match = opts[:exists]
        res.select {|d| d[:exists] == match}
      else
        res
      end
    end
    
    # legacy implementation of mget for backwards compat
    def legacy_mget(body)
      request(:get, path_uri("/_mget"), {}, body)
    end

    # Implements the Analyze API
    # Ex:
    #    server.analyze("Candles", analyzer: :snowball)
    #    # => #<Hashie::Mash tokens=[#<Hashie::Mash end_offset=7 position=1 start_offset=0 token="candl" type="<ALPHANUM>">]>
    # as per: http://www.elasticsearch.org/guide/reference/api/admin-indices-analyze.html
    def analyze(text, analysis_params)
      request(:get, path_uri("/_analyze"), analysis_params) do |req|
        req.body = text
      end
    end

    # Implements the Aliases API
    # Ex:
    # server.aliases({actions: {add: {index: :my_index, alias: :my_alias}}})
    # as per: http://www.elasticsearch.org/guide/reference/api/admin-indices-aliases.html
    def aliases(body=nil)
      if body
        request(:post, path_uri("/_aliases"), {}, body)
      else
        request(:get, path_uri("/_aliases"))
      end
    end

    # Perform a refresh, making all indexed documents available
    def refresh
      do_refresh
    end

    # Full path to the server root dir
    def path_uri(path=nil)
      @uri.to_s + path.to_s
    end

    # Handy way to query the server, returning *only* the body
    # Will raise an exception when the status is not in the 2xx range
    def request(method, path, params={}, body=nil, headers={}, &block)
      req = http.build_request(method)
      req.path = path
      req.params.update(Util.clean_params(params)) if params
      req.body = body
      req.headers.update(headers) if headers
      block.call(req) if block
      logger.debug { Util.curl_format(req) }

      @request_mtx.synchronize {
        env = req.to_env(http)
        check_response(http.app.call(env))
      }
    end

    private


    # Internal use only
    # Check response codes from request
    def check_response(res)
      if res.status >= 200 && res.status <= 299
        res.body
      elsif [404, 410].include? res.status
        err_str = "Error processing request: (#{res.status})! #{res.env[:method]} URL: #{res.env[:url]}"
        err_str << "\n Resp Body: #{res.body}"
        raise RequestError::NotFound.new(res), err_str
      else
        err_str = "Error processing request (#{res.status})! #{res.env[:method]} URL: #{res.env[:url]}"
        err_str << "\n Resp Body: #{res.body}"
        raise RequestError.new(res), err_str
      end
    end
  end
end
