require "rubypython"

module Bosh::QingCloud

  class QingCloudSDK

    def initialize(qingcloud_params)
      @region = qingcloud_params[:region]
      @access_key_id = qingcloud_params[:access_key_id]
      @secret_access_key = qingcloud_params[:secret_access_key]
      RubyPython.start
      @qingcloudpick = RubyPython.import("qingcloud.iaas")
      @conn = @qingcloudpick.connect_to_zone(@region, @access_key_id, @secret_access_key)
    end

    def describe_instances(instances_id)
      instances = []
      instances << instances_id 
      return @conn.describe_instances(instances,
        image_id = [],
        instance_type = [],
        status = [],
        search_word = [],
        verbose = 0,
        offset = 0,
        limit = 50)
    end

  end
end			
