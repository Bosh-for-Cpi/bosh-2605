# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

Bosh::Agent::Infrastructure.new("qingcloud").infrastructure

describe Bosh::Agent::Infrastructure::Qingcloud::Settings do
  let(:qingcloud_settings) { Bosh::Agent::Infrastructure::Qingcloud::Settings.new }

  describe :get_settings do
    let(:settings) { {"vm" => "test_vm", "disks" => "test_disks"} }

    it "should load settings" do
      qingcloud_settings.should_receive(:setup_openssh_key)
      Bosh::Agent::Infrastructure::Qingcloud::Registry.should_receive(:get_settings).and_return(settings)

      loaded_settings = qingcloud_settings.load_settings
      loaded_settings.should == settings
    end
  end

  describe :setup_openssh_key do
    let(:test_authorized_keys) { File.join(Dir.mktmpdir, "test_auth") }

    it "should setup the public OpenSSH key" do
      Bosh::Agent::Infrastructure::Qingcloud::Registry.should_receive(:get_openssh_key).and_return("test_key")
      qingcloud_settings.stub(:authorized_keys).and_return(test_authorized_keys)
      FileUtils.should_receive(:mkdir_p).with(File.dirname(test_authorized_keys))
      FileUtils.should_receive(:chmod).twice.and_return(true)
      FileUtils.should_receive(:chown).twice.and_return(true)

      qingcloud_settings.setup_openssh_key
      File.open(test_authorized_keys, "r") { |f| f.read.should == "test_key" }
    end

    it "should do nothing if registry doesn't returns a public OpenSSH key" do
      Bosh::Agent::Infrastructure::Qingcloud::Registry.should_receive(:get_openssh_key).and_return(nil)
      FileUtils.should_not_receive(:mkdir_p)
      FileUtils.should_not_receive(:chown)

      qingcloud_settings.setup_openssh_key
    end
  end

  describe :get_network_settings do
    it "should raise unsupported network exception for unknown  network" do
      network_properties = { "type" => "unknown" }
      expect {
        network_settings = qingcloud_settings.get_network_settings("test", network_properties)
      }.to raise_error Bosh::Agent::StateError, /Unsupported network type/
    end

    it "should get nothing for manual networks" do
      network_properties = {}
      network_settings = qingcloud_settings.get_network_settings("test", network_properties)
      network_settings.should be_nil
    end

    it "should get nothing for vip networks" do
      network_properties = { "type" => "vip" }
      network_settings = qingcloud_settings.get_network_settings("test", network_properties)
      network_settings.should be_nil
    end

    it "should get network settings for dhcp networks" do
      net_info = double("net_info", default_gateway_interface: "eth0",
                                    default_gateway: "1.2.3.1",
                                    primary_dns: "1.1.1.1",
                                    secondary_dns: "2.2.2.2")
      Bosh::Agent::Util.should_receive(:get_network_info).and_return(net_info)

      network_properties = { "type" => "dynamic" }
      network_settings = qingcloud_settings.get_network_settings("test", network_properties)
      network_settings.should_not be_nil
    end
  end
end