require 'spec_helper'

describe Stretcher::Cluster do

  let(:server) { Stretcher::Server.new(ES_URL, :logger => DEBUG_LOGGER) }
  let(:cluster) { server.cluster }

  describe :health do

    it 'should return the health' do
      cluster.health.should be_a Hashie::Mash
      cluster.health.status.should_not be_nil
    end

  end

end
