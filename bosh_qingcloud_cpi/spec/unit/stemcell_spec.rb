require 'spec_helper'

describe Bosh::QingCloud::Stemcell do
  describe ".find" do
    it "should return an AMI if given an id for an existing one" do
      fake_qingcloud_ami = double("image", exists?: true)
      region = double("region", images: {'ami-exists' => fake_qingcloud_ami})
      described_class.find(region, "ami-exists").ami.should == fake_qingcloud_ami
    end

    it "should raise an error if no AMI exists with the given id" do
      fake_qingcloud_ami = double("image", exists?: false)
      region = double("region", images: {'ami-doesntexist' => fake_qingcloud_ami})
      expect {
        described_class.find(region, "ami-doesntexist")
      }.to raise_error Bosh::Clouds::CloudError, "could not find AMI 'ami-doesntexist'"
    end
  end

  describe "#image_id" do
    let(:fake_qingcloud_ami) { double("image", id: "my-id") }
    let(:region) { double("region") }

    it "returns the id of the ami object" do
      stemcell = described_class.new(region, fake_qingcloud_ami)
      stemcell.image_id.should eq('my-id')
    end
  end

  describe "#delete" do
    let(:fake_qingcloud_ami) { double("image", exists?: true, id: "ami-xxxxxxxx") }
    let(:region) { double("region", images: {'ami-exists' => fake_qingcloud_ami}) }

    context "with real stemcell" do
      it "should deregister the ami" do
        stemcell = described_class.new(region, fake_qingcloud_ami)

        stemcell.should_receive(:memoize_snapshots).ordered
        fake_qingcloud_ami.should_receive(:deregister).ordered
        Bosh::QingCloud::ResourceWait.stub(:for_image).with(image: fake_qingcloud_ami, state: :deleted)
        stemcell.should_receive(:delete_snapshots).ordered

        stemcell.delete
      end
    end

    context "with light stemcell" do
      it "should fake ami deregistration" do
        stemcell = described_class.new(region, fake_qingcloud_ami)

        stemcell.stub(:memoize_snapshots)
        fake_qingcloud_ami.should_receive(:deregister).and_raise(QingCloud::EC2::Errors::AuthFailure)
        Bosh::QingCloud::ResourceWait.should_not_receive(:for_image)

        stemcell.delete
      end
      # QingCloud::EC2::Errors::AuthFailure
    end

    context 'when the AMI is not found after deletion' do
      it 'should not propagate a QingCloud::Core::Resource::NotFound error' do
        stemcell = described_class.new(region, fake_qingcloud_ami)

        stemcell.should_receive(:memoize_snapshots).ordered
        fake_qingcloud_ami.should_receive(:deregister).ordered
        resource_wait = double('Bosh::QingCloud::ResourceWait')
        Bosh::QingCloud::ResourceWait.stub(new: resource_wait)
        resource_wait.stub(:for_resource).with(
          resource: fake_qingcloud_ami, errors: [], target_state: :deleted, state_method: :state).and_raise(
          QingCloud::Core::Resource::NotFound)
        stemcell.should_receive(:delete_snapshots).ordered

        stemcell.delete
      end
    end
  end

  describe "#memoize_snapshots" do
    let(:fake_qingcloud_object) { double("fake", :to_hash => {
        "/dev/foo" => {:snapshot_id => 'snap-xxxxxxxx'}
    })}
    let(:fake_qingcloud_ami) do
      image = double("image", exists?: true, id: "ami-xxxxxxxx")
      image.should_receive(:block_device_mappings).and_return(fake_qingcloud_object)
      image
    end
    let(:region) { double("region", images: {'ami-exists' => fake_qingcloud_ami}) }

    it "should memoized the snapshots used by the AMI" do
      stemcell = described_class.new(region, fake_qingcloud_ami)

      stemcell.memoize_snapshots

      stemcell.snapshots.should == %w[snap-xxxxxxxx]
    end
  end

  describe "#delete_snapshots" do
    let(:fake_qingcloud_ami) { double("image", exists?: true, id: "ami-xxxxxxxx") }
    let(:snapshot) { double('snapshot') }
    let(:region) do
      region = double("region")
      region.stub(:images => {'ami-exists' => fake_qingcloud_ami})
      region.stub_chain(:snapshots, :[]).and_return(snapshot)
      region
    end

    it "should delete all memoized snapshots" do
      stemcell = described_class.new(region, fake_qingcloud_ami)
      stemcell.stub(:snapshots).and_return(%w[snap-xxxxxxxx])

      snapshot.should_receive(:delete)

      stemcell.delete_snapshots
    end
  end
end
