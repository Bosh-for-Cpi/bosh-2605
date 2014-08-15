require 'spec_helper'
require 'bosh/dev/hwcloud/micro_bosh_deployment_manifest'
require 'yaml'

module Bosh::Dev::Hwcloud
  describe MicroBoshDeploymentManifest do
    subject { MicroBoshDeploymentManifest.new(env, net_type) }
    let(:env) { {} }
    let(:net_type) { 'dynamic' }

    its(:filename) { should eq('micro_bosh.yml') }

    it 'is writable' do
      expect(subject).to be_a(Bosh::Dev::WritableManifest)
    end

    describe '#to_h' do
      before do
        env.merge!(
          'BOSH_HWCLOUD_VIP_DIRECTOR_IP' => 'vip',
          'BOSH_HWCLOUD_MANUAL_IP' => 'ip',
          'BOSH_HWCLOUD_NET_ID' => 'net_id',
          'BOSH_HWCLOUD_AUTH_URL' => 'auth_url',
          'BOSH_HWCLOUD_USERNAME' => 'username',
          'BOSH_HWCLOUD_API_KEY' => 'api_key',
          'BOSH_HWCLOUD_TENANT' => 'tenant',
          'BOSH_HWCLOUD_REGION' => 'region',
          'BOSH_HWCLOUD_PRIVATE_KEY' => 'private_key_path',
        )
      end

      context 'when net_type is "manual"' do
        let(:net_type) { 'manual' }
        let(:expected_yml) { <<YAML }
---
name: microbosh-hwcloud-manual

logging:
  level: DEBUG

network:
  type: manual
  vip: vip
  ip: ip
  cloud_properties:
    net_id: net_id

resources:
  persistent_disk: 4096
  cloud_properties:
    instance_type: m1.small

cloud:
  plugin: hwcloud
  properties:
    hwcloud:
      url: url
      access_key_id: 6D9EA5E06E03E40C79FCCD501F3A9D7B
      key: key
      signature_method: HmacSHA256
      signature_version: 1
      version: 1
      region_name: 中国华北
      availability_zone: b451c1ea3c8d4af89d03e5cacf1e4276
      default_key_name: jenkins
      default_security_groups:
      - default 
      state_timeout: 300
      wait_resource_poll_interval: 5
      connection_options:
        connect_timeout: 60

    # Default registry configuration needed by CPI
    registry:
      endpoint: http://admin:admin@localhost:25889
      user: admin
      password: admin

apply_spec:
  agent:
    blobstore:
      address: vip
    nats:
      address: vip
  properties:
    director:
      max_vm_create_tries: 15
YAML

        it 'generates the correct YAML' do
          expect(subject.to_h).to eq(Psych.load(expected_yml))
        end
      end

      context 'when net_type is "dynamic"' do
        let(:net_type) { 'dynamic' }
        let(:expected_yml) { <<YAML }
---
name: microbosh-hwcloud-dynamic
logging:
  level: DEBUG
network:
  type: dynamic
  vip: vip
  cloud_properties:
    net_id: net_id
resources:
  persistent_disk: 4096
  cloud_properties:
    instance_type: m1.small
cloud:
  plugin: hwcloud
  properties:
    hwcloud:
      url: url
      access_key_id: 6D9EA5E06E03E40C79FCCD501F3A9D7B
      key: key
      signature_method: HmacSHA256
	  signature_version: 1
      version: 1
      region_name: 中国华北
      availability_zone: b451c1ea3c8d4af89d03e5cacf1e4276
      default_key_name: jenkins      
      default_security_groups:
      - default
      state_timeout: 300
      wait_resource_poll_interval: 5
      connection_options:
        connect_timeout: 60
    registry:
      endpoint: http://admin:admin@localhost:25889
      user: admin
      password: admin
apply_spec:
  agent:
    blobstore:
      address: vip
    nats:
      address: vip
  properties:
    director:
      max_vm_create_tries: 15
YAML

        it 'generates the correct YAML' do
          expect(subject.to_h).to eq(Psych.load(expected_yml))
        end
      end

      context 'when BOSH_OPENSTACK_STATE_TIMEOUT is specified' do
        it 'uses given env variable value (converted to a float) as a state_timeout' do
          value = double('state_timeout', to_f: 'state_timeout_as_float')
          env.merge!('BOSH_OPENSTACK_STATE_TIMEOUT' => value)
          expect(subject.to_h['cloud']['properties']['hwcloud']['state_timeout']).to eq('state_timeout_as_float')
        end
      end

      context 'when BOSH_OPENSTACK_STATE_TIMEOUT is an empty string' do
        it 'uses 300 (number) as a state_timeout' do
          env.merge!('BOSH_OPENSTACK_STATE_TIMEOUT' => '')
          expect(subject.to_h['cloud']['properties']['hwcloud']['state_timeout']).to eq(300)
        end
      end

      context 'when BOSH_OPENSTACK_STATE_TIMEOUT is not specified' do
        it 'uses 300 (number) as a state_timeout' do
          env.merge!('BOSH_OPENSTACK_STATE_TIMEOUT' => nil)
          expect(subject.to_h['cloud']['properties']['hwcloud']['state_timeout']).to eq(300)
        end
      end

      context 'when BOSH_OPENSTACK_CONNECTION_TIMEOUT is specified' do
        it 'uses given env variable value (converted to a float) as a connect_timeout' do
          value = double('connection_timeout', to_f: 'connection_timeout_as_float')
          env.merge!('BOSH_OPENSTACK_CONNECTION_TIMEOUT' => value)
          expect(subject.to_h['cloud']['properties']['hwcloud']['connection_options']['connect_timeout']).to eq('connection_timeout_as_float')
        end
      end

      context 'when BOSH_OPENSTACK_CONNECTION_TIMEOUT is an empty string' do
        it 'uses 60 (number) as a connect_timeout' do
          env.merge!('BOSH_OPENSTACK_CONNECTION_TIMEOUT' => '')
          expect(subject.to_h['cloud']['properties']['hwcloud']['connection_options']['connect_timeout']).to eq(60)
        end
      end

      context 'when BOSH_OPENSTACK_CONNECTION_TIMEOUT is not specified' do
        it 'uses 60 (number) as a connect_timeout' do

          env.merge!('BOSH_OPENSTACK_CONNECTION_TIMEOUT' => nil)
          expect(subject.to_h['cloud']['properties']['hwcloud']['connection_options']['connect_timeout']).to eq(60)
        end
      end
    end

    its(:director_name) { should match(/microbosh-hwcloud-/) }

    describe '#cpi_options' do
      before do
        env.merge!(
          'BOSH_HWCLOUD_URL' => 'fake-auth-url',
          'BOSH_HWCLOUD_USERNAME' => 'fake-username',
          'BOSH_HWCLOUD_API_KEY' => 'fake-api-key',
          'BOSH_HWCLOUD_TENANT' => 'fake-tenant',
          'BOSH_HWCLOUD_REGION' => 'fake-region',
          'BOSH_HWCLOUD_PRIVATE_KEY' => 'fake-private-key-path',
        )
      end

      it 'returns cpi options' do
        expect(subject.cpi_options).to eq(
          'hwcloud' => {
            'url': url
            'access_key_id' => 6D9EA5E06E03E40C79FCCD501F3A9D7B
            'key' => key
            'signature_method' =>  HmacSHA256
            'signature_version' =>  1
            'version' =>  1
            'region_name' =>  中国华北
            'availability_zone' =>  b451c1ea3c8d4af89d03e5cacf1e4276
            'default_key_name' => jenkins            
            'default_security_groups' => ['default'],
            'state_timeout' => 300,
            'wait_resource_poll_interval' => 5,
            'connection_options' => {
              'connect_timeout' => 60,
            }
          },
          'registry' => {
            'endpoint' => 'http://admin:admin@localhost:25889',
            'user' => 'admin',
            'password' => 'admin',
          },
        )
      end

      context 'when BOSH_HWCLOUD_REGISTRY_PORT is provided' do
        before do
          env.merge!('BOSH_HWCLOUD_REGISTRY_PORT' => '25880')
        end

        it 'sets the registry endpoint' do
          expect(subject.cpi_options['registry']['endpoint']).to eq('http://admin:admin@localhost:25880')
        end
      end
    end
  end
end
