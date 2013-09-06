module Stretcher
  class Alias < EsComponent

    def initialize(index, name, options = {})
      @index = index
      @server = index.server
      @name = name
      @logger = options[:logger] || server.logger
    end

    # Create the alias
    def create(options = {})
      request(:put) do |req|
        req.body = {
          actions: [
            add: options.merge(:alias => @name)
          ]
        }
      end
    end

    # Search an alias
    def search(options = {})
      prefixed_path = @server.path_uri("/#{@name}/_search")
      raw = @server.request(:get, prefixed_path, {}, nil, {}) do |req|
        req.body = options
      end
      Stretcher::SearchResults.new(:raw => raw)
    end

    # Delete an alias
    def delete
      request(:delete)
    end

    # Determine if an alias exists
    def exist?
      request(:get)
      true
    rescue Stretcher::RequestError::NotFound
      false
    end

    private

    # Full path to server root
    def path_uri(path = nil)
      p = @index.path_uri("_alias/#{@name}")
      path ? p << "/#{path}" : p
    end

  end
end
