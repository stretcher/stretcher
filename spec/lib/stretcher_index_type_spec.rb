require 'spec_helper'

describe Stretcher::Index do
  let(:server) { Stretcher::Server.new(ES_URL) }
  let(:index) { server.index('foo') }
  let(:type) { index.type('bar') }

  it "should be existentially aware" do
    type.delete rescue nil
    type.exists?.should be_false
    mapping = {"bar" => {"properties" => {"message" => {"type" => "string"}}}}
    type.put_mapping mapping
    type.exists?.should be_true
    type.get_mapping.should == mapping
  end

  describe "searching" do
    before do
      @doc = {message: "hello"}
    end

    it "should search and find the right doc" do
      match_text = 'hello'
      type.put(123123, @doc)
      sleep 1
      res = type.search({}, {query: {match: {message: match_text}}})
      res.results.first.message.should == @doc[:message]
    end
  end

  describe "put/get" do
    before do
      @doc = {message: "hello!"}
    end
    
    it "should put correctly" do
      type.put(987, @doc).should_not be_nil
    end
    
    it "should get individual documents correctly" do
      type.get(987).message.should == @doc[:message]
    end

    it "should get individual raw documents correctly" do
      res = type.get(987, true)
      res["_id"].should == "987"
      res["_source"].message.should == @doc[:message]
    end

    it "should update individual docs correctly" do
      type.update(987, script: "ctx._source.message = 'Updated!'")
      type.get(987).message.should == 'Updated!'
    end
    
    it "should delete individual docs correctly" do
      type.exists?(987).should be_true
      type.delete(987)
      type.exists?(987).should be_false      
    end
  end
end
