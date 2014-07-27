# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::HwCloud
  ##
  # Represents HwCloud server network config. HwCloud server has single NIC
  # with a dynamic or manual IP's address and (optionally) a single floating
  # IP address which server itself is not aware of (vip). Thus we should
  # perform a number of sanity checks for the network spec provided by director
  # to make sure we don't apply something HwCloud doesn't understand how to
  # deal with.
  class NetworkConfigurator
    include Helpers

    ##
    # Creates new network spec
    #
    # @param [Hash] spec Raw network spec passed by director
    def initialize(spec)
      unless spec.is_a?(Hash)
        raise ArgumentError, "Invalid spec, Hash expected, #{spec.class} provided"
      end

      @logger = Bosh::Clouds::Config.logger
      @network = nil
      @vip_network = nil
      @security_groups = []
      @net_id = nil

      spec.each_pair do |name, network_spec|
        network_type = network_spec["type"] || "manual"

        case network_type
          when "dynamic"
            cloud_error("Must have exactly one dynamic or manual network per instance") if @network
            @network = DynamicNetwork.new(name, network_spec)

          when "manual"
            cloud_error("Must have exactly one dynamic or manual network per instance") if @network
            @network = ManualNetwork.new(name, network_spec)

          when "vip"
            cloud_error("More than one vip network") if @vip_network
            @vip_network = VipNetwork.new(name, network_spec)

          else
            cloud_error("Invalid network type `#{network_type}': HwCloud " \
                        "CPI can only handle `dynamic', 'manual' or `vip' " \
                        "network types")
        end
      end

      cloud_error("At least one dynamic or manual network should be defined") if @network.nil?
    end

    ##
    # Applies network configuration to the vm
    #
    # @param [Bosh::HwCloud::HwCloudSDK] hwcloud hwcloudsdk interface
    # @param [Hash] server hwcloud instances to
    #   configure
    def configure(hwcloud, instance)
      @network.configure(hwcloud, instance)

      if @vip_network
        @vip_network.configure(hwcloud, instance)
      else
        # If there is no vip network we should disassociate any elastic IP
        # currently held by instance (as it might have had elastic IP before)

        if !instance["instancesSet"]["instancesSet"][0]["publicIpSet"]["publicIpSet"].empty?
          @ip = instance["instancesSet"]["instancesSet"][0]["publicIpSet"]["publicIpSet"][0]["publicIp"]
        end

        if @ip
          @logger.info("Disassociating elastic IP `#{@ip}' " \
                       "from instance `#{instance["instance_set"]["instancesSet"][0]["instanceId"]}'")
          hwcloud.dissociate_address(@ip)
        end
      end
    end

    ##
    # Returns the security groups for this network configuration, or
    # the default security groups if the configuration does not contain
    # security groups
    #
    # @param [Array] default Default security groups
    # @return [Array] security groups
    def security_groups(default)
      if @security_groups.empty? && default
        default
      else
        @security_groups.sort
      end
    end

    ##
    # Returns the private IP address for this network configuration
    #
    # @return [String] private ip address
    def private_ip
      @network.is_a?(ManualNetwork) ? @network.private_ip : nil
    end

    ##
    # Returns the nics for this network configuration
    #
    # @return [Array] nics
    def nics
      nic = {}
      nic["net_id"] = @net_id if @net_id
      nic["v4_fixed_ip"] = @network.private_ip if @network.is_a? ManualNetwork
      nic.any? ? [nic] : []
    end

    private

    ##
    # Extracts the security groups from the network configuration
    #
    # @param [Hash] network_spec Network specification
    # @return [Array] security groups
    # @raise [ArgumentError] if the security groups in the network_spec is not an Array
    def extract_security_groups(network_spec)
      if network_spec && network_spec["cloud_properties"]
        cloud_properties = network_spec["cloud_properties"]
        if cloud_properties && cloud_properties.has_key?("security_groups")
          unless cloud_properties["security_groups"].is_a?(Array)
            raise ArgumentError, "security groups must be an Array"
          end
          return cloud_properties["security_groups"]
        end
      end
      []
    end

    ##
    # Extracts the network ID from the network configuration
    #
    # @param [Hash] network_spec Network specification
    # @return [Hash] network ID
    def extract_net_id(network_spec)
      if network_spec && network_spec["cloud_properties"]
        cloud_properties = network_spec["cloud_properties"]
        if cloud_properties && cloud_properties.has_key?("net_id")
          return cloud_properties["net_id"]
        end
      end
      nil
    end

  end
end
