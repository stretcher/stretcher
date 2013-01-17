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
  
  it "should check existence properly" do
    index.delete rescue nil
    index.exists?.should be_false
    index.create
    index.exists?.should be_true
  end

  it "should put mappings for new types correctly" do
    create_tweet_mapping
  end

  it "should bulk index documents properly" do
    seed_corpus
  end

  # TODO: Actually use two indexes
  it "should msearch across the index returning all docs" do
    seed_corpus
    index.msearch.total.should == corpus.length
  end
end
