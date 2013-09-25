require 'spec_helper'

describe Stretcher::Server do
  let(:server) do
    server = Stretcher::Server.new(ES_URL, :logger => DEBUG_LOGGER)
    i = server.index('foo')
    i.delete rescue Stretcher::RequestError::NotFound
    i.create
    server
  end

  it "should initialize cleanly" do
    server.class.should == Stretcher::Server
  end

  it 'sets log level from options' do
    server = Stretcher::Server.new(ES_URL, :log_level => :info)
    server.logger.level.should == Logger::INFO
  end
  
  it 'sets timeouts from options' do
    server = Stretcher::Server.new(ES_URL, :read_timeout => 5, :open_timeout => 2)
    server.http.options[:timeout].should == 5
    server.http.options[:open_timeout].should == 2
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

  it 'logs requests correctly' do
    server.logger.should_receive(:debug) do |&block|
      block.call.should == %{curl -XGET 'http://localhost:9200/_analyze?analyzer=snowball' -d 'Candles' '-H Accept: application/json' '-H Content-Type: application/json' '-H User-Agent: Stretcher Ruby Gem #{Stretcher::VERSION}'}
    end
    server.analyze("Candles", :analyzer => :snowball)
  end

  describe ".path_uri" do
    context "uri contains trailing /" do
      subject { Stretcher::Server.new("http://example.com/").path_uri("/foo") }
      it { should eq ("http://example.com/foo") }
    end

    context "uri contains no trailing /" do
      subject { Stretcher::Server.new("http://example.com").path_uri("/foo") }
      it { should eq ("http://example.com/foo") }
    end

    context "server lives in a subdirectory" do
      subject { Stretcher::Server.new("http://example.com/mysubdir/").path_uri("/foo") }      
      it { should eq ("http://example.com/mysubdir/foo") }
    end
  end

  describe "#get_alias" do
    let(:request_url) { "_alias/bar" }
    let(:http_response) { double("http_response") }
    let(:exception) { Stretcher::RequestError::NotFound.new(http_response) }

    it "sends a request to the correct endpoint with an alias that exists" do
      expect(server).to receive(:request).with(:get, request_url) { :foo }
      expect(server.get_alias("bar")).to eq(:foo)
    end

    it "sends a request to the correct endpoint with an alias that does not exist" do
      expect(server).to receive(:request).with(:get, request_url).and_raise(exception)
      expect(http_response).to receive(:status) { 404 }

      expect(server.get_alias("bar")).to eq({})
    end

    it "sends a request to the correct endpoint and gets and error response" do
      expect(server).to receive(:request).with(:get, request_url).and_raise(exception)
      expect(http_response).to receive(:status) { 410 }

      expect { server.get_alias("bar") }.to raise_error(exception)
    end

    it "should return an empty array if no aliases exist" do
      expect(server.get_alias("bar")).to eq({})
    end

    it "should return a hash of the aliases if at least one exists" do
      server.aliases(:actions => [{ :add => { :index => "foo", :alias => "bar" }}])
      expect(server.get_alias("bar")).to eq({"foo" => {"aliases" => {"bar" => {}}}})
    end
  end

end
