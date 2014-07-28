module Bosh::Deployer::InfrastructureDefaults
  HWCLOUD = {
    'name' => nil,
    'logging' => {
      'level' => 'INFO'
    },
    'dir' => nil,
    'network' => {
      'type' => 'dynamic',
      'cloud_properties' => {}
    },
    'env' => {
      'bosh' => {
        'password' => nil
      }
    },
    'resources' => {
      'persistent_disk' => 4096,
      'cloud_properties' => {
        'instance_type' => 'm1.small',
        'availability_zone' => nil
      }
    },
    'cloud' => {
      'plugin' => 'hwcloud',
      'properties' => {
        'hwcloud' => {
          'url' => nil,
          'access_key_id' => nil,
          'key' => nil,
          'signature_method' => nil,
          'signature_nonce' => nil,
          'signature_version' => nil,
          'version' => nil,
          'region_name' => nil,
          'availability_zone' => nil,
          'default_key_name' => nil,
          'wait_resource_poll_interval' => 5,
          'default_security_groups' => [],
          'ssh_user' => 'vcap'
        },
        'registry' => {
          'endpoint' => 'http://admin:admin@localhost:25889',
          'user' => 'admin',
          'password' => 'admin'
        },
        'agent' => {
          'ntp' => [],
          'blobstore' => {
            'provider' => 'local',
            'options' => {
              'blobstore_path' => '/var/vcap/micro_bosh/data/cache'
            }
          },
          'mbus' => nil
        }
      }
    },
    'apply_spec' => {
      'properties' => {},
      'agent' => {
        'blobstore' => {},
        'nats' => {}
      }
    }
  }
end
