module Stretcher

  # Represents an Alias in elastic search.
  # Generally should be used via Index#alias(name)
  class Alias < EsComponent

    attr_reader :name

    def initialize(index, name, options = {})
      @index = index
      @server = index.server
      @name = name
      @logger = options[:logger] || server.logger
    end

    # Get the index context of this alias (use it as if it was the index
    # which it represents)
    #
    #   my_alias.index_context.search({ query: { match_all: {} } })
    def index_context
      @server.index(@name)
    end

    # Create the alias in elastic search with the given options
    #
    #   my_alias.create({ filter: { term: { user_id: 1 } } })
    def create(options = {})
      request(:put) do |req|
        req.body = {
          :actions => [
            :add => options.merge(:alias => @name)
          ]
        }
      end
    end

    # Delete an alias from elastic search
    #
    #   my_alias.delete
    def delete
      request(:delete)
    end

    # Determine whether an alias by this name exists
    #
    #   my_alias.exist? # true
    def exist?
      request(:get)
      true
    rescue Stretcher::RequestError::NotFound
      false
    end

    private

    # Full path to this alias
    def path_uri(path = nil)
      p = @index.path_uri("_alias/#{@name}")
      path ? p << "/#{path}" : p
    end

  end
end
