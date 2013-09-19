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
                                       '_type' => 'type_name'
                                     }]
                       }
                     })
  end

  context 'merges in select keys' do
    subject(:search_result) {
      Stretcher::SearchResults.new(result).documents.first
    }
    
    its(:_score) { should == 255 }
    its(:_id) { should == 2 }
    its(:_index) { should == 'index_name' }
    its(:_type) { should == 'type_name' }
  end
end
