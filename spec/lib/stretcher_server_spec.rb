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

  it "should properly set alternate faraday options if requested" do
    # This spec could work better, but it's hard to reach into the
    # guts of faraday
    conf_called = false
    configurator = lambda {|builder|
      builder.adapter :net_http
      conf_called = true
    }
    srv = Stretcher::Server.new(ES_URL, {:faraday_configurator => configurator})
    conf_called.should be_true
  end

  it "should properly return that our server is up" do
    server.up?.should be_true
  end

  it "should check the stats w/o error" do
    server.stats
  end

  it "should perform alias operations properly" do
    # Tear down any leftovers from previous runs
    server.aliases(:actions => [{:remove => {:alias => :foo_alias}}]) if server.index(:foo_alias).exists?
    server.index(:foo).delete if server.index(:foo).exists?
    server.index(:foo).create
    server.aliases(:actions => [{:add => {:index => :foo, :alias => :foo_alias}}])

    server.index(:foo_alias).get_settings.should == server.index(:foo).get_settings

    server.aliases[:foo][:aliases].keys.should include 'foo_alias'
  end

  it "should check the status w/o error" do
    server.status.ok.should be_true
  end

  it "should refresh w/o error" do
    server.refresh.ok.should be_true
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

  it "execute the analysis API and return an expected result" do
    analyzed = server.analyze("Candles", :analyzer => :snowball)
    analyzed.tokens.first.token.should == 'candl'
  end
end
