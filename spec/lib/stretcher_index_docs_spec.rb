require 'spec_helper'

describe Stretcher::IndexDocs do
  let(:server) { Stretcher::Server.new(ES_URL, logger: DEBUG_LOGGER) }
  let(:index) { ensure_test_index(server, :foo) }
  let(:mapping) do
    {"properties" => {"message" => {"type" => "text"}}}
  end
  let(:docs) { index.docs }

  before(:each) do
    docs.delete_query(match_all: {})

    index.refresh
    index.put_mapping({
                        "properties" => {
                          "message" => {"type" => "text", analyzer: "snowball", "store": true},
                          "username" => {"type" => "text"}
                        }})
  end

  it "should be existentially aware" do
    docs = index.docs
    docs.exists?(1).should eq false
    d = docs.put(1, {message: 'test'})
    docs.exists?(d['_id']).should eq true
  end

  describe "searching" do
    before do
      @doc = {message: "hello"}

      docs.put(123123, @doc)
      index.refresh
    end

    it "should search and find the right doc" do
      res = docs.search(query: {match: {message: @doc[:message]}})
      res.results.first.message.should == @doc[:message]
    end

    it "should build results when _source is not included in loaded fields" do
      res = docs.search(query: {match_all: {}}, stored_fields: ['message'])
      res.results.first.message.should == [@doc[:message]]
    end

    it "should build results when no document fields are selected" do
      res = docs.search(query: {match_all: {}}, stored_fields: ['_id'])
      res.results.first.should have_key '_id'
    end

    it "should add _highlight field to resulting documents when present" do
      res = docs.search(query: {match: {message: 'hello'}}, highlight: {fields: {message: {}}})
      res.documents.first.message.should == @doc[:message]
      res.documents.first.should have_key '_highlight'
    end
  end

  describe 'mget' do
    let(:doc_one) { {message: "message one!"} }
    let(:doc_two) { {message: "message two!"} }

    before do
      docs.put(988, doc_one)
      docs.put(989, doc_two)
    end

    it 'fetches multiple documents by id' do
      docs.mget([988, 989]).docs.count.should == 2
      docs.mget([988, 989]).docs.first._source.message.should == 'message one!'
      docs.mget([988, 989]).docs.last._source.message.should == 'message two!'
    end

    it 'allows options to be passed through' do
      response = docs.mget([988, 989], stored_fields: 'message')
      response.docs.first.fields.message.should == ['message one!']
      response.docs.last.fields.message.should == ['message two!']
    end
  end

  describe "ops on individual docs" do
    before(:each) do
      @doc = {message: "hello!"}
      @put_res = docs.put(987, @doc, {refresh: :wait_for})
    end

    describe "put" do
      it "should put correctly, with options" do
        res = docs.put(987, @doc, if_seq_no: @put_res['_seq_no'], if_primary_term: @put_res['_primary_term'])
        res._version.should == @put_res['_version'] + 1
      end

      it "should post correctly, with options" do
        res = docs.post(@doc, refresh: true)
        res._version.should == 1
      end
    end

    describe "get" do
      it "should get individual documents correctly" do
        docs.get(987).message.should == @doc[:message]
      end

      it "should return nil when retrieving non-extant docs" do
        lambda {
          docs.get(898323329)
          docs.get(898323329)
        }.should raise_exception(Stretcher::RequestError::NotFound)
      end

      it "should get individual fields given a String, passing through additional options" do
        res = docs.get(987, {stored_fields: 'message'})
        res.message.first.should == @doc[:message]
      end

      it "should get individual fields given an Array, passing through additional options" do
        res = docs.get(987, {stored_fields: ['message']})
        res.message.first.should == @doc[:message]
      end

      it "should have source and other fields accessible when raw=true" do
        res = docs.get(987, {stored_fields: ['message', '_source']}, true)
        res._source.message == @doc[:message]
        res.fields.message.first.should == @doc[:message]
      end

      it "should get individual raw documents correctly" do
        res = docs.get(987, {}, true)
        res["_id"].should == "987"
        res["_source"].message.should == @doc[:message]
      end

      it "should get individual raw documents correctly with legacy API" do
        res = docs.get(987, true)
        res["_id"].should == "987"
        res["_source"].message.should == @doc[:message]
      end
    end

    describe 'explain' do
      it "should explain a query" do
        docs.exists?(987).should eq(true)
        index.refresh
        res = docs.explain(987, {query: {match_all: {}}})
        res.should have_key('explanation')
      end

      it 'should allow options to be passed through' do
        index.refresh
        docs.explain(987, {query: {match_all: {}}}, {stored_fields: 'message'}).get.fields.message.should == ['hello!']
      end
    end

    it "should update individual docs correctly using ctx.source" do
      pending "figure out how we want to handle turning groovy on (maybe use mustache?)"
      raise NotImplementedError
      #type.update(987, :script => "ctx._source.message = 'Updated!'")
      #type.get(987).message.should == 'Updated!'
    end

    it "should update individual docs correctly using doc" do
      docs.update(987, doc: {message: 'Updated!'})
      docs.get(987).message.should == 'Updated!'
    end

    it "should update individual docs correctly using doc and fields" do
      response = docs.update(987, {doc: {message: 'Updated!'}}, _source_includes: ['message'])
      response.get._source.message.should == 'Updated!'
    end

    it "should delete by query correctly" do
      res = docs.delete_query({match_all: {}}, refresh: true)
      index.refresh
      docs.exists?(987).should == false
    end

    it "should delete individual docs correctly" do
      docs.exists?(987).should == true
      docs.delete(987)
      docs.exists?(987).should == false
    end

    it "should allow params to be passed to delete" do
      es_doc = docs.get(987, {}, true)
      lambda { docs.delete(987, if_primary_term: es_doc['_primary_term'], if_seq_no: es_doc['_seq_no'] + 1) }.should raise_exception
      docs.delete(987, if_primary_term: es_doc['_primary_term'], if_seq_no: es_doc['_seq_no'])
      docs.exists?(987).should == false
    end
  end
end
