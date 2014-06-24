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

      @logger.info("Associating instance `#{instance["instances"][0]}' " \
                   "with elastic IP `#{@ip}'")

      # New elastic IP reservation supposed to clear the old one,
      # so no need to disassociate manually. Also, we don't check
      # if this IP is actually an allocated EC2 elastic IP, as
      # API call will fail in that case.

      ret = qingcloud.associate_eip(@ip, instance["instances"][0])
      cloud_error("associate eip for vip network is fail. ret_info = `#{ret}'") if ret["ret_code"] != 0

    end
  end
end


