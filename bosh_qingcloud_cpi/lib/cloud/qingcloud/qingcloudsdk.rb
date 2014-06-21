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

    def describe_instances(instance_id)
      instances = []
      instances << instance_id 
      return @conn.describe_instances(instances,
                                      image_id = [],
                                      instance_type = [],
                                      status = [],
                                      search_word = [],
                                      verbose = 0,
                                      offset = 0,
                                      limit = 0)
    end

    def terminate_instances(instance_id)
      instances = []
      instances << instance_id 
      return @conn.terminate_instances(instances)
    end

    def restart_instances(instance_id)
      instances = []
      instances << instance_id
      return @conn.restart_instances(instances)
    end

    def describe_volumes(volume_id)
      volumes = []
      volumes << vm_id
      return @conn.describe_volumes(volumes,
                                    instance_id = [],
                                    status = [],
                                    search_word = [],
                                    verbose = 0,
                                    offset = 0,
                                    limit = 0)
    end

    def create_volumes(size, volume_name, count)
      return @conn.create_volumes(size, volume_name, count)
    end

    # Attach one or more volumes to same instance
    # @param volumes : an array including IDs of the volumes you want to attach.
    # @param instance : the ID of instance the volumes will be attached to.
    def attach_volumes(volumes, instance)
      return @conn.attach_volumes(volumes, instance)
    end

    def describe_images(stemcell_id)
      images = []
      images << stemcell_id
      return @conn.describe_images(images,
                                  os_family = [],
                                  processor_type = [],
                                  status = [],
                                  visibility = [],
                                  provider = [],
                                  verbose = 0,
                                  search_word = [],
                                  offset = 0,
                                  limit = 0)
    end

  end
end
