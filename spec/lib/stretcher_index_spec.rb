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
    [
     {:text => "Foo", "_type" => 'tweet', "_id" => 'fooid'},
     {:text => "Bar", "_type" => 'tweet', "_id" => 'barid'},
     {:text => "Baz", "_type" => 'tweet', "id" => 'bazid'} # Note we support both _id and id
    ]
  }

  def create_tweet_mapping
    mdata = {:tweet => {:properties => {:text => {:type => :string}}}}
    index.type(:tweet).put_mapping(mdata)
  end

  def seed_corpus
    create_tweet_mapping
    index.bulk_index(corpus)
    index.refresh
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

  it "should bulk index documents properly" do
    seed_corpus
    corpus.each {|doc|
      index.type(doc["_type"]).get(doc["_id"] || doc["id"]).text.should == doc[:text]
    }
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
    before do
      seed_corpus
      q2_text = corpus.first[:text]
      queries = [
                 {:query => {:match_all => {}}},
                 {:query => {:match => {:text => q2_text}}}
                ]
      @res = index.msearch(queries)
    end
    
    it "should return an array of Stretcher::SearchResults" do
      @res.length.should == 2
      @res[0].class.should == Stretcher::SearchResults
    end

    it "should return the query results in order" do
      # First query returns all docs, second only one
      @res[0].results.length.should == corpus.length
      @res[1].results.length.should == 1
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
