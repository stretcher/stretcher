module Stretcher
  # Conveniently represents elastic search results in a more compact fashion
  #
  # Available properties:
  #
  # * raw : The raw response from elastic search
  # * total : The total number of matched docs
  # * facets : the facets hash
  # * results : The hit results with _id merged in to _source
  class SearchResults
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
    def total
      @total ||= raw_plain['hits']['total']
    end

    # Returns the facet data from elasticsearch
    # Equivalent to raw[:facets]
    def facets
      @facets ||= raw[:facets]
    end

    # Returns a 'prettier' version of elasticsearch results
    # Also aliased as +docs+
    # This will:
    #
    # 1. Return either '_source' or 'fields' as the base of the result
    # 2. Merge any keys beginning with a '_' into it as well (such as '_score')
    # 3. Copy the 'highlight' field into '_highlight'
    #
    def documents
      # This function and its helpers are side-effecty for speed
      @documents ||= raw[:hits][:hits].map do |hit|
        doc = extract_source(hit)
        copy_underscores(hit, doc)
        copy_highlight(hit, doc)
        doc
      end
    end
    alias_method :docs, :documents

    # DEPRECATED!
    # Call #documents instead!
    def results
      documents
    end

    private

    def extract_source(hit)
      # Memoize the key, since it will be uniform across results
      @doc_key ||= if hit.key?(:_source)
                     :_source
                   elsif hit.key?(:fields)
                     :fields
                   else
                     nil
                   end

      Hashie::Mash.new(@doc_key ? hit[@doc_key] : Hashie::Mash.new)
    end

    def copy_underscores(hit, doc)
      # Copy underscore keys into the document
      hit.each do |k,v|
        doc[k] = v if k && k[0] == "_"
      end

      doc
    end

    def copy_highlight(hit, doc)
      if highlight = hit["highlight"]
        doc[:_highlight] = highlight
      end
      doc
    end
  end
end
