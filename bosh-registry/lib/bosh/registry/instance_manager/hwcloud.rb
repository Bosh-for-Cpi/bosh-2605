# Copyright (c) 2009-2013 VMware, Inc.

module Bosh::Registry

  class InstanceManager

    class Hwcloud < InstanceManager
    
      def initialize(cloud_config)
        validate_options(cloud_config)

        @logger = Bosh::Registry.logger

        @hwcloud_properties = cloud_config['hwcloud']

        @hwcloud_options = {
	  :provider => 'HwCloud',
          :url => @hwcloud_properties['url'],
          :HWSAccessKeyId => @hwcloud_properties['access_key_id'],
          :Version =>  @hwcloud_properties['version'],
          :SignatureMethod => @hwcloud_properties['signature_method'],
         # :SignatureNonce => @hwcloud_properties['signature_nonce'],
          :SignatureVersion => @hwcloud_properties['signature_version'],
          :RegionName => @hwcloud_properties['region_name'],
          :Key => @hwcloud_properties['key']
        }
      end

      def hwcloud
        @hwcloudsdk = HwCloud::HwCloudSdk.new(@hwcloud_options)
      end
      
      def validate_options(cloud_config)
        unless cloud_config.has_key?('hwcloud') &&
            cloud_config['hwcloud'].is_a?(Hash) &&
            cloud_config['hwcloud']['url'] &&
            cloud_config['hwcloud']['access_key_id'] &&
            cloud_config['hwcloud']['version'] &&
            cloud_config['hwcloud']['signature_method'] &&
        #    cloud_config['hwcloud']['signature_nonce'] &&
            cloud_config['hwcloud']['signature_version'] &&
            cloud_config['hwcloud']['region_name'] &&                                                            
            cloud_config['hwcloud']['key'] 
          raise ConfigError, 'Invalid HwCloud configuration parameters'
        end
      end


      # Get the list of IPs belonging to this instance
      def instance_ips(instance_id)
        # If we get an Unauthorized error, it could mean that the HwCloud auth token has expired, so we are
        # going renew the fog connection one time to make sure that we get a new non-expired token.
        retried = false
        begin
          options = {
            :'InstanceId[0]' => "#{instance_id}"
          }
          instance  = hwcloud.describe_instances(options)
        rescue Excon::Errors::Unauthorized => e
          unless retried
            retried = true
            @hwcloud = nil
            retry
          end
          raise ConnectionError, "Unable to connect to HwCloud API: #{e.message}"
        end
        raise InstanceNotFound, "Instance `#{instance_id}' not found" if  instance["instancesSet"].nil?
        private_ip_addresses = ""
        floating_ip_addresses = ""
        return (private_ip_addresses + floating_ip_addresses).compact
      end

    end

  end

end
