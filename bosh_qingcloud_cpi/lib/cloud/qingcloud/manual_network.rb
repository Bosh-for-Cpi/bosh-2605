module Bosh::QingCloud
  ##
  #
  class ManualNetwork < Network

    attr_reader :subnet

    # create manual network
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
      @manual_spec = spec
    end

    def private_ip
      @ip
    end

    def configure(qingcloud, instance)
      router_id = @manual_spec["cloud_properties"]["router_id"]
      if router_id.nil?
        raise Bosh::Clouds::CloudError, "router  required for manual network"
      end

      static_ip = @manual_spec["ip"]
      if static_ip.nil?
        raise Bosh::Clouds::CloudError, "static ip required for manual network"
      end

      if instance["instances"] != nil 
        instance_id = instance["instances"][0]
      elsif instance["instance_set"] != nil
        instance_id = instance["instance_set"][0]["instance_id"]
      end

      var static = {static_type: '3',
                  val1: instance_id,
                  val2: 'fixed-address=' +  static_ip}
      statics = [static]
      ret = qingcloud.add_router_statics(router_id,statics)
      cloud_error("add router statics for manual network is fail. ret_info = `#{ret}'") if ret["ret_code"] != 0
      ret = qingcloud.update_routers(router_id)
      cloud_error("update statics for manual network is fail. ret_info = `#{ret}'") if ret["ret_code"] != 0
      qingcloud.restart_instances(instance_id)
    end
  end
end