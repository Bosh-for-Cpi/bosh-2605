# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::HwCloud

  class VipNetwork < Network

    ##
    # Creates a new vip network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
    end

    ##
    # Configures vip network
    #
    # @param [HwCloud:EC2] ec2 EC2 client
    # @param [HwCloud::EC2::Instance] instance EC2 instance to configure
    def configure(hwcloud, instance)
      if @ip == ""
        cloud_error("No IP provided for vip network `#{@name}'")
      end

      instance_id = instance["instancesSet"]["instancesSet"][0]["instanceId"]

      options={
       :'PublicIp[0]' => @ip,
      }

      address_info = hwcloud.describe_addresses(options)
      if address_info["addressesSet"] == 'null'
        cloud_error("Floating IP #{@ip} not allocated")
      else
        if address_info["addressesSet"]["addressesSet"][0]["isAssige"] == "allocated"
          @logger.info("Associating server `#{server.id}' " \
              "with floating IP `#{@ip}'")

          options_param={
            :PublicIp => @ip,
            :InstanceId => instance_id,
            :Reverse => true
          }

          ret = hwcloud.associate_address(options_param)

        elsif address_info["addressesSet"]["addressesSet"][0]["isAssige"] == "associated"       
           cloud_error("Floating IP #{@ip} has been used")
        end
      end
    end
  end
end


