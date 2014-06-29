# Copyright (c) 2009-2013 VMware, Inc.
require "rubypython"

module Bosh::Registry

  class InstanceManager

    class Qingcloud  < InstanceManager

      def qingcloud_init(qingcloud_params)
        region = qingcloud_params[:qingcloud_region]
        access_key_id = qingcloud_params[:qingcloud_access_key_id]
        secret_access_key = qingcloud_params[:qingcloud_secret_access_key]
        RubyPython.start
        @qingcloudpick = RubyPython.import("qingcloud.iaas")
        @conn = @qingcloudpick.connect_to_zone(region, access_key_id, secret_access_key)
      end

      def initialize(cloud_config)
        validate_options(cloud_config)

        @logger = Bosh::Registry.logger

        @qingcloud_properties = cloud_config['qingcloud']

        @qingcloud_options = {
          :provider => 'QingCloud',
          :qingcloud_region => @qingcloud_properties['region'],
          :qingcloud_access_key_id => @qingcloud_properties['access_key_id'],
          :qingcloud_secret_access_key => @qingcloud_properties['secret_access_key'],
          :qingcloud_endpoint_type => @qingcloud_properties['endpoint_type'],
          :connection_options => @qingcloud_properties['connection_options']
        }
      end

      def qingcloud
        @qingcloud ||= qingcloud_init(@qingcloud_options)
      end
      
      def validate_options(cloud_config)
        unless cloud_config.has_key?('qingcloud') &&
            cloud_config['qingcloud'].is_a?(Hash) &&
            cloud_config['qingcloud']['region'] &&
            cloud_config['qingcloud']['access_key_id'] &&
            cloud_config['qingcloud']['secret_access_key'] 
          raise ConfigError, 'Invalid QingCloud configuration parameters'
        end
      end

      def describe_instances(instance_id)
        instances = []
        instances << instance_id 
        ret = qingcloud.describe_instances(instances,
                                      image_id = [],
                                      instance_type = [],
                                      status = [],
                                      search_word = [],
                                      verbose = 0,
                                      offset = 0,
                                      limit = 0)
        return RubyPython::Conversion.ptorDict(ret.pObject.pointer)
      end

      # Get the list of IPs belonging to this instance
      def instance_ips(instance_id)
        # If we get an Unauthorized error, it could mean that the QingCloud auth token has expired, so we are
        # going renew the fog connection one time to make sure that we get a new non-expired token.
        retried = false
        begin
          instance  = describe_instances(instance_id)
        rescue Excon::Errors::Unauthorized => e
          unless retried
            retried = true
            @qingcloud = nil
            retry
          end
          raise ConnectionError, "Unable to connect to QingCloud API: #{e.message}"
        end
        raise InstanceNotFound, "Instance `#{instance_id}' not found   #{instance}" if  instance["total_count"] == 0
        private_ip_addresses = ""  # instance["instance_set"][0]["vxnets"][0]["private_ip"]
        floating_ip_addresses = ""  # instance["instance_set"][0]["eip"]["eip_addr"]
        return (private_ip_addresses + floating_ip_addresses).compact
      end

    end

  end

end
