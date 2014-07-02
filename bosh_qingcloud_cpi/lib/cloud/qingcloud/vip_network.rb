# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::QingCloud

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
    # @param [QingCloud:EC2] ec2 EC2 client
    # @param [QingCloud::EC2::Instance] instance EC2 instance to configure
    def configure(qingcloud, instance)      
      if @ip == ""
        cloud_error("No IP provided for vip network `#{@name}'")
      end

      if instance["instances"] != nil 
        instance_id = instance["instances"][0]
      elsif instance["instance_set"] != nil
        instance_id = instance["instance_set"][0]["instance_id"]
      end
      @logger.info("Associating instance `#{instance_id}' " \
                   "with elastic IP `#{@ip}'")
      ip_info = qingcloud.describe_eips(nil,@ip)
      if ip_info == nil || ip_info["total_count"] != 1
        cloud_error("Could found IP: `#{@ip}'")
      end

      # New elastic IP reservation supposed to clear the old one,
      # so no need to disassociate manually. Also, we don't check
      # if this IP is actually an allocated EC2 elastic IP, as
      # API call will fail in that case.
      
      vip_id = ip_info["eip_set"][0]["eip_id"]
      ret = qingcloud.associate_eip(vip_id, instance_id)
      cloud_error("associate eip for vip network is fail. ret_info = `#{ret}'") if ret["ret_code"] != 0

    end
  end
end


