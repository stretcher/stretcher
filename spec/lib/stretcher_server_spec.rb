require 'spec_helper'

describe Stretcher::Server do
  let(:server) { Stretcher::Server.new(ES_URL) }
  
  it "should initialize cleanly" do
    server.class.should == Stretcher::Server
  end

  it "should properly return that our server is up" do
    server.up?.should be_true
  end
  
  it "should beget an index object cleanly" do
    server.index('foo').class.should == Stretcher::Index
  end
end
