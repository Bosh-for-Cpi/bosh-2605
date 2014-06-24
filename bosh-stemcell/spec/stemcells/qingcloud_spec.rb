require 'spec_helper'

describe 'QingCloud Stemcell' do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('qingcloud') }
    end
  end
end
