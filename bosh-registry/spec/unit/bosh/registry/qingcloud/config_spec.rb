# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::Registry::InstanceManager do

  describe "configuring QingCloud registry" do

    before(:each) do
      @config = valid_config
      @config["cloud"] = {
        "plugin" => "qingcloud",
        "qingcloud" => {
          "region" => "gd1",
		  "access_key_id" => "foo-key",
		  "secret_access_key" => "foo-secret"
        }
      }
    end

    it "validates presence of qingcloud cloud option" do
      @config["cloud"].delete("qingcloud")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid QingCloud configuration parameters/)
    end

    it "validates qingcloud cloud option is a Hash" do
      @config["cloud"]["qingcloud"] = "foobar"
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid QingCloud configuration parameters/)
    end

    it "validates presence of region cloud option" do
      @config["cloud"]["qingcloud"].delete("region")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid QingCloud configuration parameters/)
    end

    it "validates presence of access_key_id cloud option" do
      @config["cloud"]["qingcloud"].delete("access_key_id")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid QingCloud configuration parameters/)
    end

    it "validates presence of secret_access_key cloud option" do
      @config["cloud"]["qingcloud"].delete("secret_access_key")
      expect {
        Bosh::Registry.configure(@config)
      }.to raise_error(Bosh::Registry::ConfigError, /Invalid QingCloud configuration parameters/)
    end

  end

end