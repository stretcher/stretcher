# Stretcher

A concise, fast ElasticSearch client designed to reflect the actual elastic search API as closely as possible. Elastic search's API is complex, and mostly documented on the Elastic Search Guide. This client tries to stay out of your way more than others making advanced techniques easier to implement, and making debugging Elastic Search's sometimes cryptic errors easier.

# Features

* Cleanly matches up to elastic search's JSON api
* Efficiently re-uses connections on a per-server object basis (via net/http/persistent)
* Supports efficient bulk indexing operations
* Returns most responses in convenient Hashie::Mash form
* Configurable logging
* Pure, threadsafe, ruby

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'stretcher'
```

## Usage

### Basic Usage

```ruby   
# First Create a server
server = Stretcher::Server.new('http://localhost:9200')
# Delete an index (in case you already have this one)
server.index(:foo).delete rescue nil
# Create an index
server.index(:foo).create(mappings: {tweet: {properties: {text: {type: 'string'}}}})
# Add a document
server.index(:foo).type(:tweet).put(123, {text: 'Hello'})
# Retrieve a document
server.index(:foo).type(:tweet).get(123)
# Perform a search (Returns a Stretcher::SearchResults instance)
res = server.index(:foo).search({size: 12}, {query: {match_all: {}}})
res.class   # Stretcher::SearchResults
res.total   # => 1
res.facets  # => nil
res.results # => [#<Hashie::Mash _id="123" text="Hello">]
res.raw     # => #<Hashie::Mash ...> Raw JSON from the search
```

### Block Syntax

```ruby
# A nested block syntax is also supported.
# with_server takes the same args as #new, but is amenable to blocks
Stretcher::Server.with_server('http://localhost:9200') {|srv|
  srv.index(:foo) {|idx|
    idx.type(:bar) {|t| [t.exists?, t.get_mapping] }
  } 
}
# => [true, #<Hashie::Mash bar=...>]
```

### Multi Search
    
```ruby
# Within a single index
server.index(:foo).msearch([{query: {match_all: {}}}])
# => Returns an array of Stretcher::SearchResults
# Across multiple indexes
server.msearch([{index: :foo}, {query: {match_all: {}}}])
# => Returns an array of Stretcher::SearchResults
```

### Bulk Indexing
    
```ruby
docs = [{"_type" => "tweet", "_id" => 91011, "text" => "Bulked"}]
server.index(:foo).bulk_index(docs)
```

### Rails Integration

Stretcher is a low level-client, but it was built as a part of a full suite of Rails integration tools.
While not yet open-sourced, you can read our detailed blog post: [integrating Stretcher with Rails](http://blog.andrewvc.com/elasticsearch-rails-stretcher-at-pose).

### Full Documentation

This README documents only part of stretcher's API. The full documentation for stretcher is available in its [full rdocs](http://rdoc.info/github/PoseBiz/stretcher/master/frames).

## Running Specs

Running the specs requires an operational Elastic Search server on http://localhost:9200.
The test suite is not to be trusted, don't count on your indexes staying around!

Specs may be run with `rake spec`

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
