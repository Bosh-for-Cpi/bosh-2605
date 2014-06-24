# Copyright (c) 2009-2013 VMware, Inc.

module Bosh::Registry

  class InstanceManager

    class Qingcloud < InstanceManager

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
        @qingcloud ||= Bosh::QingCloud::QingCloudSDK.new(@qingcloud_options)
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

      # Get the list of IPs belonging to this instance
      def instance_ips(instance_id)
        # If we get an Unauthorized error, it could mean that the QingCloud auth token has expired, so we are
        # going renew the fog connection one time to make sure that we get a new non-expired token.
        retried = false
        begin
          instance  = qingcloud.servers.find { |s| s.name == instance_id }
        rescue Excon::Errors::Unauthorized => e
          unless retried
            retried = true
            @qingcloud = nil
            retry
          end
          raise ConnectionError, "Unable to connect to QingCloud API: #{e.message}"
        end
        raise InstanceNotFound, "Instance `#{instance_id}' not found" unless instance
        return (instance.private_ip_addresses + instance.floating_ip_addresses).compact
      end

    end

  end

end
