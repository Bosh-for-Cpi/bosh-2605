# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::HwCloud::Cloud do
  it 'should delete the stemcell' do
    stemcell = double(Bosh::HwCloud::Stemcell)

    cloud = mock_cloud do |_, region|
      Bosh::HwCloud::StemcellFinder.stub(:find_by_region_and_id).with(region, 'ami-xxxxxxxx').and_return(stemcell)
    end

    stemcell.should_receive(:delete)

    cloud.delete_stemcell('ami-xxxxxxxx')
  end
end
