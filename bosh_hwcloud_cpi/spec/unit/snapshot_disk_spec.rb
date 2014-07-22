require 'spec_helper'

describe Bosh::HwCloud::Cloud do
  describe '#snapshot_disk' do
    let(:volume) { double(HwCloud::EC2::Volume, id: 'vol-xxxxxxxx') }
    let(:snapshot) { double(HwCloud::EC2::Snapshot, id: 'snap-xxxxxxxx') }
    let(:attachment) { double(HwCloud::EC2::Attachment, device: '/dev/sdf') }
    let(:metadata) {
      {
          agent_id: 'agent',
          instance_id: 'instance',
          director_name: 'Test Director',
          director_uuid: '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
          deployment: 'deployment',
          job: 'job',
          index: '0'
      }
    }

    it 'should take a snapshot of a disk' do
      cloud = mock_cloud do |ec2|
        ec2.volumes.should_receive(:[]).with('vol-xxxxxxxx').and_return(volume)
      end


      volume.should_receive(:attachments).and_return([attachment])
      volume.should_receive(:create_snapshot).with('deployment/job/0/sdf').and_return(snapshot)

      Bosh::HwCloud::ResourceWait.should_receive(:for_snapshot).with(
        snapshot: snapshot, state: :completed
      )

      Bosh::HwCloud::TagManager.should_receive(:tag).with(snapshot, :agent_id, 'agent')
      Bosh::HwCloud::TagManager.should_receive(:tag).with(snapshot, :instance_id, 'instance')
      Bosh::HwCloud::TagManager.should_receive(:tag).with(snapshot, :director_name, 'Test Director')
      Bosh::HwCloud::TagManager.should_receive(:tag).with(snapshot, :director_uuid, '6d06b0cc-2c08-43c5-95be-f1b2dd247e18')
      Bosh::HwCloud::TagManager.should_receive(:tag).with(snapshot, :device, '/dev/sdf')
      Bosh::HwCloud::TagManager.should_receive(:tag).with(snapshot, 'Name', 'deployment/job/0/sdf')

      cloud.snapshot_disk('vol-xxxxxxxx', metadata)
    end

    it 'should take a snapshot of a disk not attached to any instance' do
      cloud = mock_cloud do |ec2|
        ec2.volumes.should_receive(:[]).with('vol-xxxxxxxx').and_return(volume)
      end

      volume.should_receive(:attachments).and_return([])
      volume.should_receive(:create_snapshot).with('deployment/job/0').and_return(snapshot)

      Bosh::HwCloud::ResourceWait.should_receive(:for_snapshot).with(
        snapshot: snapshot, state: :completed
      )

      Bosh::HwCloud::TagManager.should_receive(:tag).with(snapshot, :agent_id, 'agent')
      Bosh::HwCloud::TagManager.should_receive(:tag).with(snapshot, :instance_id, 'instance')
      Bosh::HwCloud::TagManager.should_receive(:tag).with(snapshot, :director_name, 'Test Director')
      Bosh::HwCloud::TagManager.should_receive(:tag).with(snapshot, :director_uuid, '6d06b0cc-2c08-43c5-95be-f1b2dd247e18')
      Bosh::HwCloud::TagManager.should_receive(:tag).with(snapshot, 'Name', 'deployment/job/0')

      cloud.snapshot_disk('vol-xxxxxxxx', metadata)
    end
  end
end
