require 'spec_helper'

describe Stretcher::IndexType do
  let(:server) { Stretcher::Server.new(ES_URL, :logger => DEBUG_LOGGER) }
  let(:index) { ensure_test_index(server, :foo) }
  let(:type) {  index.type(:bar) }

  it "should be existentially aware" do
    t = index.type(:existential)
    t.exists?.should be_false
    mapping = {"existential" => {"properties" => {"message" => {"type" => "string"}}}}
    t.put_mapping mapping
    t.exists?.should be_true
    t.get_mapping.should == mapping
  end

  before do
    type.delete_query(:match_all => {})
    index.refresh
    type.put_mapping({"bar" => {
                         "properties" => {
                           "message" => {"type" => "string", analyzer: "snowball"},
                           "username" => {"type" => "string"}
                         }}})
  end

  describe "searching" do
    before do
      @doc = {:message => "hello"}

      type.put(123123, @doc)
      index.refresh
    end

    it "should search and find the right doc" do
      res = type.search(:query => {:match => {:message => @doc[:message]}})
      res.results.first.message.should == @doc[:message]
    end

    it "should build results when _source is not included in loaded fields" do
      res = type.search(:query => {:match_all => {}}, :fields => ['message'])
      res.results.first.message.should == @doc[:message]
    end

    it "should build results when no document fields are selected" do
      res = type.search(:query => {:match_all => {}}, :fields => ['_id'])
      res.results.first.should have_key '_id'
    end

    it "should add _highlight field to resulting documents when present" do
      res = type.search(:query => {:match => {:message => 'hello'}}, :highlight => {:fields => {:message => {}}})
      res.documents.first.message.should == @doc[:message]
      res.documents.first.should have_key '_highlight'
    end
  end

  describe "document based mlt_searches" do
    let(:doc_one) {{message: "I just saw Death Wish I with charles bronson!", :_timestamp => 1366420402}}
    let(:doc_two) {{message: "Death Wish II was even better!", :_timestamp => 1366420403}}
    let(:doc_three) {{message: "Death Wish III was even better, making it the best!", :_timestamp => 1366420403}}

    before do
      type.put(1, doc_one)
      type.put(2, doc_two)
      type.put(3, doc_three)
      type.index.refresh
    end

    let (:results) {
      type.mlt(1, min_term_freq: 1, min_doc_freq: 1, fields: [:message])
    }
    
    it "should return results as SearchResults" do
      results.should be_a(Stretcher::SearchResults)
    end
    
    it "should return expected mlt results" do
      Set.new(results.docs.map(&:_id)).should == Set.new(["2", "3"])
    end
  end

  describe 'mget' do
    let(:doc_one) {{:message => "message one!", :_timestamp => 1366420402}}
    let(:doc_two) {{:message => "message two!", :_timestamp => 1366420403}}

    before do
      type.put(988, doc_one)
      type.put(989, doc_two)
    end

    it 'fetches multiple documents by id' do
      type.mget([988, 989]).docs.count.should == 2
      type.mget([988, 989]).docs.first._source.message.should == 'message one!'
      type.mget([988, 989]).docs.last._source.message.should == 'message two!'
    end

    it 'allows options to be passed through' do
      response = type.mget([988, 989], :fields => 'message')
      response.docs.first.fields.message.should == 'message one!'
      response.docs.last.fields.message.should == 'message two!'
    end
  end

  describe "ops on individual docs" do
    before do
      @doc = {:message => "hello!", :_timestamp => 1366420401}
      @put_res = type.put(987, @doc)
    end
    
    describe "put" do
      it "should put correctly, with options" do
        type.put(987, @doc, :version_type => :external, :version => 42)._version.should == 42
      end

      it "should post correctly, with options" do
        type.post(@doc, :version_type => :external, :version => 42)._version.should == 42
      end
    end

    describe "get" do
      it "should get individual documents correctly" do
        type.get(987).message.should == @doc[:message]
      end

      it "should return nil when retrieving non-extant docs" do
        lambda {
          type.get(898323329)
        }.should raise_exception(Stretcher::RequestError::NotFound)
      end

      it "should get individual fields given a String, passing through additional options" do
        res = type.get(987, {:fields => '_timestamp'})
        res._timestamp.should == @doc[:_timestamp]
        res.message.should == nil
      end

      it "should get individual fields given an Array, passing through additional options" do
        res = type.get(987, {:fields => ['_timestamp']})
        res._timestamp.should == @doc[:_timestamp]
        res.message.should == nil
      end

      it "should have source and other fields accessible when raw=true" do
        res = type.get(987, {:fields => ['_timestamp', '_source']}, true)
        res._source.message == @doc[:message]
        res.fields._timestamp.should == @doc[:_timestamp]
      end

      it "should get individual raw documents correctly" do
        res = type.get(987, {}, true)
        res["_id"].should == "987"
        res["_source"].message.should == @doc[:message]
      end

      it "should get individual raw documents correctly with legacy API" do
        res = type.get(987, true)
        res["_id"].should == "987"
        res["_source"].message.should == @doc[:message]
      end
    end
    
    describe 'explain' do
      it "should explain a query" do
        type.exists?(987).should be_true
        index.refresh
        res = type.explain(987, {:query => {:match_all => {}}})
        res.should have_key('explanation')
      end

      it 'should allow options to be passed through' do
        index.refresh
        type.explain(987, {:query => {:match_all => {}}}, {:fields => 'message'}).get.fields.message.should == 'hello!'
      end
    end
    
    it "should update individual docs correctly using ctx.source" do
      type.update(987, :script => "ctx._source.message = 'Updated!'")
      type.get(987).message.should == 'Updated!'
    end

    it "should update individual docs correctly using doc" do
      type.update(987, :doc => {:message => 'Updated!'})
      type.get(987).message.should == 'Updated!'
    end

    it "should update individual docs correctly using doc and fields" do
      response =  type.update(987, {:doc => {:message => 'Updated!'}}, :fields => 'message')
      response.get.fields.message.should == 'Updated!'      
    end

    it "should delete by query correctly" do
      type.delete_query("match_all" => {})
      index.refresh
      type.exists?(987).should be_false
    end

    it "should delete individual docs correctly" do
      type.exists?(987).should be_true
      type.delete(987)
      type.exists?(987).should be_false
    end

    it "should allow params to be passed to delete" do
      version = type.get(987, {},  true)._version
      lambda { type.delete(987, :version => version + 1) }.should raise_exception
      type.delete(987, :version => version)
      type.exists?(987).should be_false
    end
  end

  describe 'percolate' do
    before do
      index.register_percolator_query('bar', {:query => {:term => {:baz => 'qux'}}}).ok
    end

    it 'returns matching percolated queries based on the document' do
      type.percolate({:baz => 'qux'}).matches.should == ['bar']
    end
  end
end
