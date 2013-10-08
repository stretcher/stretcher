require 'spec_helper'

describe Stretcher::SearchResults do
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
end
