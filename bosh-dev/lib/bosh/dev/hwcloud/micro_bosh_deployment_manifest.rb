require 'bosh/dev/hwcloud'
require 'bosh/dev/writable_manifest'

module Bosh::Dev::Hwcloud
  class MicroBoshDeploymentManifest
    include Bosh::Dev::WritableManifest

    attr_reader :filename

    def initialize(env, net_type)
      @env = env
      @net_type = net_type
      @filename = 'micro_bosh.yml'
    end

    def to_h
      result = {
        'name' => director_name,
        'logging' => {
          'level' => 'DEBUG'
        },
        'network' => {
          'type' => net_type,
          'vip' => env['BOSH_HWCLOUD_VIP_DIRECTOR_IP'],
          'cloud_properties' => {
            'net_id' => env['BOSH_HWCLOUD_NET_ID']
          }
        },
        'resources' => {
          'persistent_disk' => 4096,
          'cloud_properties' => {
            'instance_type' => 'm1.small'
          }
        },
        'cloud' => {
          'plugin' => 'hwcloud',
          'properties' => cpi_options,
        },
        'apply_spec' => {
          'agent' => {
            'blobstore' => {
              'address' => env['BOSH_HWCLOUD_VIP_DIRECTOR_IP']
            },
            'nats' => {
              'address' => env['BOSH_HWCLOUD_VIP_DIRECTOR_IP']
            }
          },
          'properties' => {
            'director' => {
              'max_vm_create_tries' => 15
            },
          },
        },
      }

      result['network']['ip'] = env['BOSH_HWCLOUD_MANUAL_IP'] if net_type == 'manual'

      result
    end

    def director_name
      "microbosh-hwcloud-#{net_type}"
    end

    def cpi_options
      {
        'hwcloud' => {
          'url' => env['BOSH_HWCLOUD_URL'],
          'access_key_id' => env['BOSH_HWCLOUD_ACCESS_KEY_ID'],
          'key' => env['BOSH_HWCLOUD_KEY'],	
          'signature_method' => env['BOSH_HWCLOUD_SIGNATURE_METHOD'],
          'version' => env['BOSH_HWCLOUD_VERSION'],
          'region_name' => env['BOSH_HWCLOUD_REGION_NAME'],
          'state_timeout' => state_timeout,
          'wait_resource_poll_interval' => 5,
          'connection_options' => {
            'connect_timeout' => connection_timeout,
          }
        },
        'registry' => {
          'endpoint' => "http://admin:admin@localhost:#{env['BOSH_HWCLOUD_REGISTRY_PORT'] || 25889}",
          'user' => 'admin',
          'password' => 'admin',
        },
      }
    end

    private

    attr_reader :env, :net_type

    def state_timeout
      timeout = env['BOSH_HWCLOUD_STATE_TIMEOUT']
      timeout.to_s.empty? ? 300.0 : timeout.to_f
    end

    def connection_timeout
      timeout = env['BOSH_HWCLOUD_CONNECTION_TIMEOUT']
      timeout.to_s.empty? ? 60.0 : timeout.to_f
    end
  end
end
