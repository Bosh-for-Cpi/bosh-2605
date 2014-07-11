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
require 'rubypython'

require "common/exec"
require "common/thread_pool"
require "common/thread_formatter"

require "bosh/registry/client"

require "cloud"
require "cloud/qingcloud/helpers"
require "cloud/qingcloud/cloud"
require "cloud/qingcloud/version"

require "cloud/qingcloud/network_configurator"
require "cloud/qingcloud/network"
require "cloud/qingcloud/dynamic_network"
require "cloud/qingcloud/manual_network"
require "cloud/qingcloud/vip_network"
require "cloud/qingcloud/tag_manager"
require "cloud/qingcloud/qingcloudsdk"

module Bosh
  module Clouds
    Qingcloud = Bosh::QingCloud::Cloud
  end
end
