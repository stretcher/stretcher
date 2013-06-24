require 'spec_helper'

describe Stretcher::Index do
  let(:server) {
    Stretcher::Server.new(ES_URL, :logger => DEBUG_LOGGER)
  }
  let(:index) {
    i = server.index('foo')
    begin
      i.delete
    rescue Stretcher::RequestError::NotFound
    end
    server.refresh
    i.create({
      :settings => {
        :number_of_shards => 1,
        :number_of_replicas => 0
      }
    })
    # Why do both? Doesn't hurt, and it fixes some races
    server.refresh
    i.refresh
    i
  }
  let(:corpus) {
    # underscore field that are not system fields should make it through to _source
    [
     {:text => "Foo", :_text => '_Foo', "_type" => 'tweet', "_id" => 'fooid'},
     {:text => "Bar", :_text => '_Bar', "_type" => 'tweet', "_id" => 'barid'},
     {:text => "Baz", :_text => '_Baz', "_type" => 'tweet', "id" => 'bazid'}, # Note we support both _id and id
     {:username => "john", age: 25, "_type" => 'user', "_id" => 'fooid'},
     {:username => "jacob", age: 32, "_type" => 'user', "_id" => 'barid'},
     {:username => "jingleheimer", age: 54, "_type" => 'user', "id" => 'bazid'} # Note we support both _id and id
    ]
  }

  def create_tweet_mapping
    mdata = {:tweet => {:properties => {:text => {:type => :string}}}}
    index.type(:tweet).put_mapping(mdata)
  end

  def create_user_mapping
    mdata = {:user => {:properties => {:username => {:type => :string}, 
                                       :age => {:type => :integer}}}}
    index.type(:user).put_mapping(mdata)
  end

  def seed_corpus
    create_tweet_mapping
    create_user_mapping
    index.bulk_index(corpus)
    index.refresh
  end

  it 'creates an index with the correct HTTP command' do
    index.delete rescue nil

    options = { :mappings => { :movie => { :properties => { :category => { :type => 'string' } } } } }

    server.logger.should_receive(:debug) do |&block|
      block.call.should == %{curl -XPUT http://localhost:9200/foo -d '#{options.to_json}' '-H Accept: application/json' '-H Content-Type: application/json' '-H User-Agent: Stretcher Ruby Gem #{Stretcher::VERSION}'}
    end

    index.create(options)
  end

  it "should work on an existential level" do
    index.delete rescue nil
    index.exists?.should be_false
    index.create
    index.exists?.should be_true
  end

  it "should support block syntax for types" do
    exposed = nil
    res = index.type(:foo) {|t|
      exposed = t
      :retval
    }
    res.should == :retval
    exposed.class.should == Stretcher::IndexType
  end

  it "should return docs across types when issuing an mget" do
    seed_corpus
    tweet = corpus.select {|d| d['_type'] == 'tweet' }.first
    user =  corpus.select {|d| d['_type'] == 'user' }.first
    res = index.mget([{:_type => 'tweet', :_id => (tweet["_id"] || tweet['id'])},
                      {:_type => 'user', :_id => (user["_id"] || user['id']) }])
    res.length.should == 2
    equalizer = lambda {|r| [r['_type'], r['_id']] }
    res.map {|d| equalizer.call(d)}.sort.should == [tweet,user].map {|d| equalizer.call(d)}.sort
  end

  it "should return stats without error" do
    index.stats['_all'].should_not be_nil
  end

  it "should return the status without error" do
    index.status['ok'].should be_true
  end

  it "should put mappings for new types correctly" do
    create_tweet_mapping
  end

  it "should retrieve settings properly" do
    index.get_settings['foo']['settings']['index.number_of_shards'].should eq("1")
    index.get_settings['foo']['settings']['index.number_of_replicas'].should eq("0")
  end

  describe "bulk operations" do
    it "should bulk index documents properly" do
      seed_corpus
      corpus.each {|doc|
        fetched_doc = index.type(doc["_type"]).get(doc["_id"] || doc["id"], {}, true)
        fetched_doc._source.text.should == doc[:text]
        fetched_doc._source._text.should == doc[:_text]
        fetched_doc._source._id.should be_nil
        fetched_doc._source._type.should be_nil
      }
    end

    it "should bulk delete documents" do
      seed_corpus
      docs_meta = [
                   {"_type" => 'tweet', "_id" => 'fooid'},
                   {"_type" => 'tweet', "_id" => 'barid'},
                  ]
      index.mget(docs_meta).length.should == 2
      index.bulk_delete(docs_meta)
      index.refresh
      res = index.mget(docs_meta).length.should == 0
    end
  end

  it 'allows _routing to be set on bulk index documents' do
    server.index(:with_routing).delete if server.index(:with_routing).exists?
    server.index(:with_routing).create({
      :settings => {
        :number_of_shards => 1,
        :number_of_replicas => 0
      },
      :mappings => {
        :_default_ =>  {
          :_routing => { :required => true }
        }
      }
    })

    lambda {server.index(:with_routing).bulk_index(corpus)}.should raise_exception
    routed_corpus = corpus.map do |doc|
      routed_doc = doc.clone
      routed_doc['_routing'] = 'abc'
      routed_doc
    end

    server.index(:with_routing).bulk_index(routed_corpus)

    server.index(:with_routing).delete
  end

  it "should delete by query" do
    seed_corpus
    index.search(:query => {:match_all => {}}).total == 3
    index.delete_query(:match_all => {})
    index.refresh
    index.search(:query => {:match_all => {}}).total == 0
  end

  it "should search without error" do
    seed_corpus
    match_text = corpus.first[:text]
    index.refresh
    res = index.search({}, {:query => {:match => {:text => match_text}}})
    res.results.first.text.should == match_text
  end

  # TODO: Actually use two indexes
  describe "msearch" do
    let(:res) {
      seed_corpus
      q2_text = corpus.first[:text]
      queries = [
                 {:query => {:match_all => {}}},
                 {:query => {:match => {:text => q2_text}}}
                ]
      index.msearch(queries)
    }
    
    it "should return an array of Stretcher::SearchResults" do
      res.length.should == 2
      res[0].class.should == Stretcher::SearchResults
    end

    it "should return the query results in order" do
      # First query returns all docs, second only one
      res[0].results.length.should == corpus.length
      res[1].results.length.should == 1
    end

    it "should raise an error if any query is bad" do
      queries = [
                 {:query => {:match_all => {}}},
                 {:query => {:invalid_query => {}}}
                ]
      expect {
        index.msearch(queries)
      }.to raise_error(Stretcher::RequestError)
    end
  end

  it "execute the analysis API and return an expected result" do
    analyzed = server.index(:foo).analyze("Candles", :analyzer => :snowball)
    analyzed.tokens.first.token.should == 'candl'
  end

  it "should raise an exception when msearching a non-existant index" do
    lambda {
      res = server.index(:does_not_exist).msearch([{:query => {:match_all => {}}}])
    }.should raise_exception(Stretcher::RequestError)
  end
end
