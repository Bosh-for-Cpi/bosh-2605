require 'spec_helper'
require 'bosh/dev/qingcloud/micro_bosh_deployment_manifest'
require 'yaml'

module Bosh::Dev::Qingcloud
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
          'BOSH_QINGCLOUD_VIP_DIRECTOR_IP' => 'vip',
          'BOSH_QINGCLOUD_MANUAL_IP' => 'ip',
          'BOSH_QINGCLOUD_NET_ID' => 'net_id',
          'BOSH_QINGCLOUD_REGION' => 'region',
          'BOSH_QINGCLOUD_ACCESS_KEY_ID' => 'access_key_id',
          'BOSH_QINGCLOUD_SECRET_ACCESS_KEY' => 'secret_access_key',
          'BOSH_QINGCLOUD_PRIVATE_KEY' => 'private_key_path',
        )
      end

      context 'when net_type is "manual"' do
        let(:net_type) { 'manual' }
        let(:expected_yml) { <<YAML }
---
name: microbosh-qingcloud-manual

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
  plugin: qingcloud
  properties:
    qingcloud:
      region: region
      access_key_id: access_key_id
      secret_access_key: secret_access_key
      endpoint_type: publicURL
      default_key_name: jenkins
      default_security_groups:
      - default
      private_key: private_key_path
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
name: microbosh-qingcloud-dynamic
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
  plugin: qingcloud
  properties:
    qingcloud:
      region: region
      access_key_id: access_key_id
      secret_access_key: secret_access_key
      endpoint_type: publicURL
      default_key_name: jenkins
      default_security_groups:
      - default
      private_key: private_key_path
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

      context 'when BOSH_QINGCLOUD_STATE_TIMEOUT is specified' do
        it 'uses given env variable value (converted to a float) as a state_timeout' do
          value = double('state_timeout', to_f: 'state_timeout_as_float')
          env.merge!('BOSH_QINGCLOUD_STATE_TIMEOUT' => value)
          expect(subject.to_h['cloud']['properties']['qingcloud']['state_timeout']).to eq('state_timeout_as_float')
        end
      end

      context 'when BOSH_QINGCLOUD_STATE_TIMEOUT is an empty string' do
        it 'uses 300 (number) as a state_timeout' do
          env.merge!('BOSH_QINGCLOUD_STATE_TIMEOUT' => '')
          expect(subject.to_h['cloud']['properties']['qingcloud']['state_timeout']).to eq(300)
        end
      end

      context 'when BOSH_QINGCLOUD_STATE_TIMEOUT is not specified' do
        it 'uses 300 (number) as a state_timeout' do
          env.merge!('BOSH_QINGCLOUD_STATE_TIMEOUT' => nil)
          expect(subject.to_h['cloud']['properties']['qingcloud']['state_timeout']).to eq(300)
        end
      end

      context 'when BOSH_QINGCLOUD_CONNECTION_TIMEOUT is specified' do
        it 'uses given env variable value (converted to a float) as a connect_timeout' do
          value = double('connection_timeout', to_f: 'connection_timeout_as_float')
          env.merge!('BOSH_QINGCLOUD_CONNECTION_TIMEOUT' => value)
          expect(subject.to_h['cloud']['properties']['qingcloud']['connection_options']['connect_timeout']).to eq('connection_timeout_as_float')
        end
      end

      context 'when BOSH_QINGCLOUD_CONNECTION_TIMEOUT is an empty string' do
        it 'uses 60 (number) as a connect_timeout' do
          env.merge!('BOSH_QINGCLOUD_CONNECTION_TIMEOUT' => '')
          expect(subject.to_h['cloud']['properties']['qingcloud']['connection_options']['connect_timeout']).to eq(60)
        end
      end

      context 'when BOSH_QINGCLOUD_CONNECTION_TIMEOUT is not specified' do
        it 'uses 60 (number) as a connect_timeout' do

          env.merge!('BOSH_QINGCLOUD_CONNECTION_TIMEOUT' => nil)
          expect(subject.to_h['cloud']['properties']['qingcloud']['connection_options']['connect_timeout']).to eq(60)
        end
      end
    end

    its(:director_name) { should match(/microbosh-qingcloud-/) }

    describe '#cpi_options' do
      before do
        env.merge!(
          'BOSH_QINGCLOUD_REGION' => 'fake-region',
          'BOSH_ACCESS_KEY_ID' =>  'fake-access-key-id',
          'BOSH_SECRET_ACCESS_KEY' => 'fake-secret-access-key',
          'BOSH_QINGCLOUD_PRIVATE_KEY' => 'fake-private-key-path',
        )
      end

      it 'returns cpi options' do
        expect(subject.cpi_options).to eq(
          'qingcloud' => {
            'region' => 'fake-region',
            'access_key_id' =>  'fake-access-key-id',
            'secret_access_key' => 'fake-secret-access-key',
            'endpoint_type' => 'publicURL',
            'default_key_name' => 'jenkins',
            'default_security_groups' => ['default'],
            'private_key' => 'fake-private-key-path',
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

      context 'when BOSH_QINGCLOUD_REGISTRY_PORT is provided' do
        before do
          env.merge!('BOSH_QINGCLOUD_REGISTRY_PORT' => '25880')
        end

        it 'sets the registry endpoint' do
          expect(subject.cpi_options['registry']['endpoint']).to eq('http://admin:admin@localhost:25880')
        end
      end
    end
  end
end
