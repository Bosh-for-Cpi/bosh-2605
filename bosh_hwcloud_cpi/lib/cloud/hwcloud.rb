# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module HwCloud; end
end

require "httpclient"
require "pp"
require "set"
require "tmpdir"
require "securerandom"
require "yajl"
require 'rubypython'

require "common/exec"
require "common/thread_pool"
require "common/thread_formatter"

require "bosh/registry/client"

require "cloud"
require "cloud/hwcloud/helpers"
require "cloud/hwcloud/cloud"
require "cloud/hwcloud/version"

require "cloud/hwcloud/network_configurator"
require "cloud/hwcloud/network"
require "cloud/hwcloud/dynamic_network"
require "cloud/hwcloud/manual_network"
require "cloud/hwcloud/vip_network"
require "cloud/hwcloud/tag_manager"
require "cloud/hwcloud/qingcloudsdk"

module Bosh
  module Clouds
    Hwcloud = Bosh::HwCloud::Cloud
  end
end
