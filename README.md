# Stretcher

[![Gem Version](https://badge.fury.io/rb/stretcher.png)](http://badge.fury.io/rb/stretcher)
[![Build Status](https://travis-ci.org/PoseBiz/stretcher.png?branch=master)](https://travis-ci.org/PoseBiz/stretcher)
[![Code Climate](https://codeclimate.com/github/PoseBiz/stretcher.png)](https://codeclimate.com/github/PoseBiz/stretcher)
[![Coverage Status](https://coveralls.io/repos/PoseBiz/stretcher/badge.png)](https://coveralls.io/r/PoseBiz/stretcher)

A concise, fast ElasticSearch client designed to reflect the actual elastic search API as closely as possible. Elastic search's API is complex, and mostly documented on the Elastic Search Guide. This client tries to stay out of your way more than others making advanced techniques easier to implement, and making debugging Elastic Search's sometimes cryptic errors easier.

# Features

* Cleanly matches up to elastic search's JSON api
* Efficiently re-uses connections on a per-server object basis (via excon)
* Supports efficient bulk indexing operations
* Returns most responses in convenient Hashie::Mash form
* Configurable logging
* Pure, threadsafe, ruby
* Easily swap HTTP clients via Faraday
* Tested against Ruby 2.0,1.9,1.8.7, Jruby, and Rubinius

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
# Add some documents
30.times {|t| server.index(:foo).type(:tweet).put(t, {text: "Hello #{t}"}) }
# Retrieve a document
server.index(:foo).type(:tweet).get(3)
# => #<Hashie::Mash text="Hello 3">
# Perform a search (Returns a Stretcher::SearchResults instance)
res = server.index(:foo).search(size: 12, query: {match_all: {}})
res.class   # Stretcher::SearchResults
res.total   # => 30
res.results # => [#<Hashie::Mash _id="4" text="Hello 4">, ...]
res.facets  # => nil
res.raw     # => #<Hashie::Mash ...> Raw JSON from the search
```

### Block Syntax

```ruby
# A nested block syntax is also supported.
# with_server takes the same args as #new, but is amenable to blocks
Stretcher::Server.with_server('http://localhost:9200') {|srv|
  srv.index(:foo) {|idx|
    idx.type(:tweet) {|t| {exists: t.exists?, mapping: t.get_mapping} }
  }
}
# => {:exists=>true, :mapping=>#<Hashie::Mash tweet=...>}
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

### Full Documentation

This README documents only part of stretcher's API. The full documentation for stretcher is available in its [full rdocs](http://rdoc.info/github/PoseBiz/stretcher/master/frames).

### Rails Integration

Stretcher is a low level-client, but it was built as a part of a full suite of Rails integration tools.
While not yet open-sourced, you can read our detailed blog post: [integrating Stretcher with Rails](http://blog.andrewvc.com/elasticsearch-rails-stretcher-at-pose).

## Running Specs

Running the specs requires an operational Elastic Search server on http://localhost:9200.
The test suite is not to be trusted, don't count on your indexes staying around!

Specs may be run with `rake spec`

## Contributors

* [@andrewvc](https://github.com/andrewvc)
* [@aq1018](https://github.com/aq1018)
* [@akahn](https://github.com/akahn)
* [@psynix](https://github.com/psynix)
* [@cmaitchison](https://github.com/cmaitchison)
* [@fmardini](https://github.com/fmardini)
* [@chatgris](https://github.com/chatgris)
* [@alpinegizmo](https://github.com/alpinegizmo)
* [@mcolyer](https://github.com/mcolyer)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
