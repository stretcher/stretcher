module Stretcher

  # Represents a cluster of servers
  # should be reached typically through Server#cluster
  class Cluster < EsComponent

    def initialize(server, options = {})
      @server = server
      @logger = options[:logger] || server.logger
    end

    # Get the health of the cluster
    def health(options = {})
      request(:get, 'health', options)
    end

    private

    def path_uri(path = nil)
      p = @server.path_uri('/_cluster')
      path ? "#{p}/#{path}" : p
    end

  end

end
