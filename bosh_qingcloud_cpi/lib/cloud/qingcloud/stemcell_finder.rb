require 'cloud/qingcloud/light_stemcell'
require 'cloud/qingcloud/stemcell'

module Bosh::QingCloud
  class StemcellFinder
    def self.find_by_region_and_id(region, id)
      if id =~ / light$/
        LightStemcell.new(Stemcell.find(region, id[0...-6]), Bosh::Clouds::Config.logger)
      else
        Stemcell.find(region, id)
      end
    end
  end
end
