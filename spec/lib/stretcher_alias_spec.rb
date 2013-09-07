require 'spec_helper'

describe Stretcher::Alias do

  let(:server) { Stretcher::Server.new(ES_URL, :logger => DEBUG_LOGGER) }
  let(:index) { server.index(:foo) }
  let(:my_alias) { index.alias('user-1') }

  before do
    index.type(:bar).put(1, { message: 'visible', user_id: 1 })
    index.type(:bar).put(2, { message: 'hidden', user_id: 2 })
    index.refresh
  end

  describe 'creating' do

    before do
      my_alias.create(filter: {
        term: { user_id: 1 }
      })
    end

    it 'should have the alias' do
      my_alias.should exist
    end

  end

  describe 'searching' do

    it 'should be able to search with filter' do
      resp = my_alias.index_context.search(:query => { :match_all => {} })
      resp.results.map(&:message).should == ['visible']
    end

  end

  describe 'destroying' do

    before do
      my_alias.delete
    end

    it 'should have removed the alias' do
      my_alias.should_not exist
    end

  end

end
