require 'spec_helper'
require 'bosh/dev/qingcloud/bat_deployment_manifest'
require 'bosh/stemcell/archive'
require 'psych'
require 'bosh/dev/bat/director_uuid'
require 'bosh/stemcell/archive'

module Bosh::Dev::Qingcloud
  describe BatDeploymentManifest do
    subject { described_class.new(env, net_type, director_uuid, stemcell_archive) }
    let(:env) { {} }
    let(:net_type) { 'dynamic' }
    let(:director_uuid) { instance_double('Bosh::Dev::Bat::DirectorUuid', value: 'director-uuid') }
    let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', version: 13, name: 'stemcell-name') }

    its(:filename) { should eq ('bat.yml') }

    it 'is writable' do
      expect(subject).to be_a(Bosh::Dev::WritableManifest)
    end

    describe '#to_h' do
      before do
        env.merge!(
          'BOSH_QINGCLOUD_VIP_BAT_IP'       => 'vip',
          'BOSH_QINGCLOUD_STATIC_BAT_IP'    => 'fake-static-ip',
          'BOSH_QINGCLOUD_SECOND_STATIC_BAT_IP' => 'fake-second-static-ip',
          'BOSH_QINGCLOUD_NET_ID'           => 'net_id',
          'BOSH_QINGCLOUD_NETWORK_CIDR'     => 'net_cidr',
          'BOSH_QINGCLOUD_NETWORK_RESERVED' => 'net_reserved',
          'BOSH_QINGCLOUD_NETWORK_STATIC'   => 'net_static',
          'BOSH_QINGCLOUD_NETWORK_GATEWAY'  => 'net_gateway',
        )
      end

      context 'manual' do
        let(:net_type) { 'manual' }
        let(:expected_yml) { <<YAML }
---
cpi: qingcloud
properties:
  vip: vip
  static_ip: fake-static-ip
  second_static_ip: fake-second-static-ip
  uuid: director-uuid
  pool_size: 1
  stemcell:
    name: stemcell-name
    version: 13
  instances: 1
  key_name:  jenkins
  mbus: nats://nats:0b450ada9f830085e2cdeff6@vip:4222
  network:
    type: manual
    cidr: net_cidr
    reserved:
      - net_reserved
    static:
      - net_static
    gateway: net_gateway
    cloud_properties:
      security_groups: [ default ]
      net_id: net_id
YAML

        it 'generates the correct YAML' do
          expect(subject.to_h).to eq(Psych.load(expected_yml))
        end
      end

      context 'dynamic' do
        let(:net_type) { 'dynamic' }
        let(:expected_yml) { <<YAML }
---
cpi: qingcloud
properties:
  vip: vip
  static_ip: fake-static-ip
  second_static_ip: fake-second-static-ip
  uuid: director-uuid
  pool_size: 1
  stemcell:
    name: stemcell-name
    version: 13
  instances: 1
  key_name:  jenkins
  mbus: nats://nats:0b450ada9f830085e2cdeff6@vip:4222
  network:
    type: dynamic
    cloud_properties:
      security_groups: [ default ]
      net_id: net_id
YAML

        it 'generates the correct YAML' do
          expect(subject.to_h).to eq(Psych.load(expected_yml))
        end
      end
    end
  end
end
