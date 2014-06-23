# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module QingCloud; end
end

require "httpclient"
require "pp"
require "set"
require "tmpdir"
require "securerandom"
require "yajl"

require "common/exec"
require "common/thread_pool"
require "common/thread_formatter"

require "bosh/registry/client"

require "cloud"
require "cloud/qingcloud/helpers"
require "cloud/qingcloud/cloud"
require "cloud/qingcloud/version"

require "cloud/qingcloud/qingcloudsdk"
require "cloud/qingcloud/aki_picker"
require "cloud/qingcloud/network_configurator"
require "cloud/qingcloud/network"
require "cloud/qingcloud/stemcell"
require "cloud/qingcloud/stemcell_creator"
require "cloud/qingcloud/dynamic_network"
require "cloud/qingcloud/manual_network"
require "cloud/qingcloud/vip_network"
require "cloud/qingcloud/instance_manager"
require "cloud/qingcloud/tag_manager"
require "cloud/qingcloud/availability_zone_selector"
# require "cloud/qingcloud/resource_wait"

module Bosh
  module Clouds
    Qingcloud = Bosh::QingCloud::Cloud
  end
end
