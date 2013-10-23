require 'spec_helper'

describe Stretcher::SearchResults do
  let(:server) {
    Stretcher::Server.new(ES_URL, :logger => DEBUG_LOGGER)
  }
  let(:index) { ensure_test_index(server, :foo) }

  let(:result) do
    Hashie::Mash.new({
                       'facets' => [],
                       'hits' => {
                         'total' => 1,
                         'hits'  => [{
                                       '_score' => 255,
                                       '_id' => 2,
                                       '_index' => 'index_name',
                                       '_type' => 'type_name',
                                     }]
                       }
                     })
  end

  let(:result_with_hightlight) do
    Hashie::Mash.new({
                       'facets' => [],
                       'hits' => {
                         'total' => 1,
                         'hits'  => [{
                                       '_score' => 255,
                                       '_id' => 2,
                                       '_index' => 'index_name',
                                       '_type' => 'type_name',
                                       'highlight' => {'message.*' => ["meeting at <hit>protonet</hit>!"]}
                                     }]
                       }
                     })
  end


  context 'merges in underscore keys' do
    subject(:search_result) {
      Stretcher::SearchResults.new(result).documents.first
    }

    its(:_score) { should == 255 }
    its(:_id) { should == 2 }
    its(:_index) { should == 'index_name' }
    its(:_type) { should == 'type_name' }
    its(:_highlight) { should be(nil) }
  end

  context 'merges in optional keys' do
    subject(:search_result) {
      Stretcher::SearchResults.new(result_with_hightlight).documents.first
    }

    its(:_id) { should == 2 }
    its(:_highlight) { should == {'message.*' => ["meeting at <hit>protonet</hit>!"]} }
  end

  context 'result object types' do
    let(:search_result) {
      index.search(:query => {:match_all => {}})
    }

    it 'returns a plain hash for raw_plain' do
      search_result.raw_plain.should be_instance_of(::Hash)
    end

    it 'returns a hashie mash for raw' do
      search_result.raw.should be_instance_of(Hashie::Mash)
    end
  end
end
