require 'spec_helper'

describe 'HwCloud Stemcell' do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('hwcloud') }
    end
  end
end
