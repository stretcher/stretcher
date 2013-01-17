require 'spec_helper'

describe Stretcher::Index do
  let(:server) { Stretcher::Server.new(ES_URL) }
  let(:index) { server.index('foo') }
  let(:corpus) {
    [
     {text: "Foo", "_type" => 'tweet'},
     {text: "Bar", "_type" => 'tweet'},
     {text: "Baz", "_type" => 'tweet'}
    ]
  }

  def create_tweet_mapping
    mdata = {tweet:{properties: {text: {type: :string}}}}
    index.type('tweet').put_mapping(mdata)
  end

  def seed_corpus
    create_tweet_mapping
    index.bulk_index(corpus)
  end
  
  it "should work on an existential level" do
    index.delete rescue nil
    index.exists?.should be_false
    index.create
    index.exists?.should be_true
  end

  it "should return stats without error" do
    index.stats['_all'].should_not be_nil
  end

  it "should put mappings for new types correctly" do
    create_tweet_mapping
  end

  it "should retrieve settings properly" do
    index.get_settings['foo']['settings']['index.number_of_replicas'].should_not be_nil
  end

  it "should bulk index documents properly" do
    seed_corpus
  end

  # TODO: Actually use two indexes
  it "should msearch across the index returning all docs" do
    seed_corpus
    res = index.msearch([{query: {match_all: {}}}])
    res.length.should == 1
    res[0].class.should == Stretcher::SearchResults
  end
end
