require 'spec_helper'

describe Stretcher::Server do
  let(:server) { Stretcher::Server.new(ES_URL) }
  
  it "should initialize cleanly" do
    server.class.should == Stretcher::Server
  end

  it "should support the block friendly 'with_server'" do
    exposed = nil
    res = Stretcher::Server.with_server() {|s|
      exposed = s
      :retval
    }
    res.should == :retval
    exposed.class.should == Stretcher::Server
  end

  it "should properly return that our server is up" do
    server.up?.should be_true
  end

  it "should check the stats w/o error" do
    server.stats
  end

  it "should check the status w/o error" do
    server.status.ok.should be_true
  end
  
  it "should beget an index object cleanly" do
    server.index('foo').class.should == Stretcher::Index
  end

  it "should support block syntax for indexes" do
    exposed = nil
    res = server.index(:foo) {|i|
      exposed = i
      :retval
    }
    res.should == :retval
    exposed.class.should == Stretcher::Index
  end
end
