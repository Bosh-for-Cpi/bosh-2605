module Bosh::Deployer::InfrastructureDefaults
  QINGCLOUD = {
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
      'plugin' => 'qingcloud',
      'properties' => {
        'qingcloud' => {
          'auth_url' => nil,
          'username' => nil,
          'api_key' => nil,
          'tenant' => nil,
          'region' => nil,
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
