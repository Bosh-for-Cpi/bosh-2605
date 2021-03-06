# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::QingCloud::Cloud do
  let(:volume) { double(QingCloud::EC2::Volume, id: 'v-foo') }
  let(:cloud) do
    mock_cloud do |ec2|
      ec2.volumes.stub(:[]).with('v-foo').and_return(volume)
    end
  end

  before do
    Bosh::QingCloud::ResourceWait.stub(sleep_callback: 0)
  end

  it 'deletes an EC2 volume' do
    Bosh::QingCloud::ResourceWait.stub(for_volume: {volume: volume, state: :deleted})

    volume.should_receive(:delete)

    cloud.delete_disk('v-foo')
  end

  it 'retries deleting the volume if it is in use' do
    Bosh::QingCloud::ResourceWait.stub(for_volume: {volume: volume, state: :deleted})
    Bosh::Clouds::Config.stub(:task_checkpoint)

    volume.should_receive(:delete).once.ordered.and_raise(QingCloud::EC2::Errors::Client::VolumeInUse)
    volume.should_receive(:delete).ordered

    cloud.delete_disk('v-foo')
  end

  it 'raises an error if the volume remains in use after every deletion retry' do
    Bosh::Clouds::Config.stub(:task_checkpoint)

    volume.should_receive(:delete).exactly(10).times.and_raise(QingCloud::EC2::Errors::Client::VolumeInUse)

    expect {
      cloud.delete_disk('v-foo')
    }.to raise_error("Timed out waiting to delete volume `v-foo'")
  end

  it 'does a fast path delete when asked to' do
    options = mock_cloud_options['properties']
    options['qingcloud']['fast_path_delete'] = 'yes'
    cloud = mock_cloud(options) do |ec2|
      ec2.volumes.stub(:[]).with('v-foo').and_return(volume)
    end

    volume.should_receive(:delete)
    volume.should_receive(:add_tag).with('Name', {value: 'to be deleted'})
    Bosh::QingCloud::ResourceWait.should_not_receive(:for_volume)

    cloud.delete_disk('v-foo')
  end
end
