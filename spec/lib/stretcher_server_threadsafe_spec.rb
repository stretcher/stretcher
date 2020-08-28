require 'spec_helper'
# Explictly test threaded mode 
describe Stretcher::Server do
  let(:server) do
    Stretcher::Server.new(ES_URL, http_threadsafe: true, logger: DEBUG_LOGGER)
  end

  it "should initialize threadsafe mode cleanly" do
    server.class.should == Stretcher::Server
  end

  it "should properly return that our server is up" do
    server.up?.should eql true
  end

  it "should perform threaded alias operations properly" do
    t1 = Thread.new {
      server.index(:foots).delete if server.index(:foots).exists?
      server.index(:foots).create
      server.aliases(actions: [{add: {index: :foots, alias: :foots_alias}}])

      server.index(:foots_alias).get_settings.should == server.index(:foots).get_settings

      server.aliases[:foots][:aliases].keys.should include 'foots_alias'
    }
    t2 = Thread.new {
      server.index(:foots2).delete if server.index(:foots2).exists?
      server.index(:foots2).create
      server.aliases(actions: [{add: {index: :foots2, alias: :foots_alias2}}])

      server.index(:foots_alias2).get_settings.should == server.index(:foots2).get_settings

      server.aliases[:foots2][:aliases].keys.should include 'foots_alias2'
    }
    # Check the thread have not finished; they should both be running or sleeping. Any other value
    # indicates an unexpected result
    t1.status.should match /run|sleep/
    t2.status.should match /run|sleep/

    t1.join
    t2.join
  end

  it "should check the status w/o error" do
    server.status.indices.should be
  end

  it "should refresh w/o error" do
    server.refresh._shards.failed.should eql 0
  end

  it "should perform unthreaded alias operations properly" do

    server.index(:foots).delete if server.index(:foots).exists?
    server.index(:foots).create
    server.aliases(actions: [{add: {index: :foots, alias: :foots_alias}}])

    server.index(:foots_alias).get_settings.should == server.index(:foots).get_settings

    server.aliases[:foots][:aliases].keys.should include 'foots_alias'


    server.index(:foots2).delete if server.index(:foots2).exists?
    server.index(:foots2).create
    server.aliases(actions: [{add: {index: :foots2, alias: :foots_alias2}}])

    server.index(:foots_alias2).get_settings.should == server.index(:foots2).get_settings

    server.aliases[:foots2][:aliases].keys.should include 'foots_alias2'

  end

  it "should check the status w/o error" do
    server.status.indices.should be
  end

  it "should refresh w/o error" do
    server.refresh._shards.failed.should eql 0
  end

end
