require 'bosh/dev/vsphere'
require 'bosh/dev/writable_manifest'

module Bosh::Dev::Qingcloud
  class BatDeploymentManifest
    include Bosh::Dev::WritableManifest

    attr_reader :filename

    def initialize(env, net_type, director_uuid, stemcell_archive)
      @env = env
      @net_type = net_type
      @director_uuid = director_uuid
      @stemcell_archive = stemcell_archive
      @filename = 'bat.yml'
    end

    def to_h
      manifest_hash = {
        'cpi' => 'qingcloud',
        'properties' => {
          'vip' => env['BOSH_QINGCLOUD_VIP_BAT_IP'],
          'static_ip' => env['BOSH_QINGCLOUD_STATIC_BAT_IP'],
          'second_static_ip' => env['BOSH_QINGCLOUD_SECOND_STATIC_BAT_IP'],
          'uuid' => director_uuid.value,
          'pool_size' => 1,
          'stemcell' => {
            'name' => stemcell_archive.name,
            'version' => stemcell_archive.version
          },
          'instances' => 1,
          'key_name' => 'jenkins',
          'mbus' => "nats://nats:0b450ada9f830085e2cdeff6@#{env['BOSH_QINGCLOUD_VIP_BAT_IP']}:4222",
          'network' => {
            'type' => net_type,
            'cloud_properties' => {
              'net_id' => env['BOSH_QINGCLOUD_NET_ID'],
              'security_groups' => ['default']
            }
          }
        }
      }

      if net_type == 'manual'
        manifest_hash['properties']['network'].merge!(
          'cidr' => env['BOSH_QINGCLOUD_NETWORK_CIDR'],
          'reserved' => [env['BOSH_QINGCLOUD_NETWORK_RESERVED']],
          'static' => [env['BOSH_QINGCLOUD_NETWORK_STATIC']],
          'gateway' => env['BOSH_QINGCLOUD_NETWORK_GATEWAY']
        )
      end

      manifest_hash
    end

    private

    attr_reader :env, :net_type, :stemcell_archive, :director_uuid
  end
end
