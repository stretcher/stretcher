module Stretcher
  # Conveniently represents elastic count results in a more compact fashion
  #
  # Available properties:
  #
  # * raw : The raw response from elastic search
  # * count : The total number of matched docs
  class CountResults
    def initialize(raw)
      @raw_plain = raw
    end

    # Returns a plain (string keyed) hash of the raw response
    # Normally stretcher deals in Hashie::Mash-ified versions of data
    # If you have truly gigantic result sets this may matter.
    def raw_plain
      @raw_plain
    end

    # Returns a Hashie::Mash version of the raw response
    def raw
      @raw ||= Hashie::Mash.new(@raw_plain)
    end

    # Returns the total number of results
    def count
      @count ||= raw_plain['count']
    end

  end
end
