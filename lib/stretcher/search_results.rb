require 'hashie/dash'
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

    def facets
      @facets ||= raw[:facets]
    end    

    # DEPRECATED!
    # Call #documents instead!
    def results
      pretty
    end
  
    # Returns a 'prettier' version of elasticsearch results
    # This will:
    # 
    # 1. Return either '_source' or 'fields' as the base of the result
    # 2. Merge any keys beginning with a '_' into it as well (such as '_score')
    # 3. Copy the 'highlight' field into '_highlight'
    #
    def pretty
      # This function and its helpers are side-effecty for speed
      @documents ||= raw[:hits][:hits].map do |hit|
        doc = extract_source(hit)
        copy_underscores(hit, doc)
        copy_highlight(hit, doc)
        doc
      end
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
        if k && k[0] == "_"
          doc[k] = v
        end
      end
      doc
    end

    def copy_highlight(hit, doc)
      if highlight = hit.key?("highlight")
        doc[:_highlight] = highlight
      end
      doc
    end
  end
end
