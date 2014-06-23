require 'bosh/dev/qingcloud'
require 'bosh/dev/writable_manifest'

module Bosh::Dev::Qingcloud
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
          'vip' => env['BOSH_QINGCLOUD_VIP_DIRECTOR_IP'],
          'cloud_properties' => {
            'net_id' => env['BOSH_QINGCLOUD_NET_ID']
          }
        },
        'resources' => {
          'persistent_disk' => 4096,
          'cloud_properties' => {
            'instance_type' => 'm1.small'
          }
        },
        'cloud' => {
          'plugin' => 'qingcloud',
          'properties' => cpi_options,
        },
        'apply_spec' => {
          'agent' => {
            'blobstore' => {
              'address' => env['BOSH_QINGCLOUD_VIP_DIRECTOR_IP']
            },
            'nats' => {
              'address' => env['BOSH_QINGCLOUD_VIP_DIRECTOR_IP']
            }
          },
          'properties' => {
            'director' => {
              'max_vm_create_tries' => 15
            },
          },
        },
      }

      result['network']['ip'] = env['BOSH_QINGCLOUD_MANUAL_IP'] if net_type == 'manual'

      result
    end

    def director_name
      "microbosh-qingcloud-#{net_type}"
    end

    def cpi_options
      {
        'qingcloud' => {
          'region' => env['BOSH_QINGCLOUD_REGION'],
          'access_key_id' => env['BOSH_QINGCLOUD_ACCESS_KEY_ID'],
          'secret_access_key' => env['BOSH_QINGCLOUD_SECRET_ACCESS_KEY'],		  
          'endpoint_type' => 'publicURL',
          'default_key_name' => 'jenkins',
          'default_security_groups' => ['default'],
          'private_key' => env['BOSH_QINGCLOUD_PRIVATE_KEY'],
          'state_timeout' => state_timeout,
          'wait_resource_poll_interval' => 5,
          'connection_options' => {
            'connect_timeout' => connection_timeout,
          }
        },
        'registry' => {
          'endpoint' => "http://admin:admin@localhost:#{env['BOSH_QINGCLOUD_REGISTRY_PORT'] || 25889}",
          'user' => 'admin',
          'password' => 'admin',
        },
      }
    end

    private

    attr_reader :env, :net_type

    def state_timeout
      timeout = env['BOSH_QINGCLOUD_STATE_TIMEOUT']
      timeout.to_s.empty? ? 300.0 : timeout.to_f
    end

    def connection_timeout
      timeout = env['BOSH_QINGCLOUD_CONNECTION_TIMEOUT']
      timeout.to_s.empty? ? 60.0 : timeout.to_f
    end
  end
end
