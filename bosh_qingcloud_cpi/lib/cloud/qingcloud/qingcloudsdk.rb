require "rubypython"

module Bosh::QingCloud

  class QingCloudSDK

    def initialize(qingcloud_params)
      region = qingcloud_params[:region]
      access_key_id = qingcloud_params[:access_key_id]
      secret_access_key = qingcloud_params[:secret_access_key]
      RubyPython.start
      @qingcloudpick = RubyPython.import("qingcloud.iaas")
      @conn = @qingcloudpick.connect_to_zone(region, access_key_id, secret_access_key)
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
      volumes << volume_id
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

    def detach_volumes(volumes, instance)
      return @conn.detach_volumes(volumes, instance)
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

    def create_images(instance_id)
      return @conn.capture_instance(instance_id,
                                    image_name = "")
    end

    def delete_volumes(disk_id)
      volumes = []
      volumes << disk_id
      ret = @conn.delete_volumes(volumes)
      ret_info = RubyPython::Conversion.ptorDict(ret.pObject.pointer)
      ret_info
    end
    
    def delete_images(stemcell_id)
      images = []
      images << stemcell_id
      return @conn.delete_images(images)
    end

    def create_snapshots(resources, snapshot_name)
      resources_id = []
      resources_id << resources

      return @conn.create_snapshots(resources_id, snapshot_name, is_full=0)
    end

    def delete_snapshots(snapshots)
      snapshots_id = []
      snapshots_id << snapshots
      return @conn.delete_snapshots(snapshots_id)
    end

    def describe_snapshot(snapshot_id)
      snapshots = []
      snapshots << snapshot_id
      return @conn.describe_snapshots(snapshots,
                                      resource_id = [],
                                      snapshot_type = 1,
                                      root_id = [],
                                      status = [],
                                      verbose = 0,
                                      search_word = [],
                                      offset = 0,
                                      limit = 0)
    end
    
    def describe_security_groups(disk_id)
      volumes = []
      volumes << disk_id
      ret = @conn.delete_volumes(volumes)
      ret_info = RubyPython::Conversion.ptorDict(ret.pObject.pointer)
      ret_info
    end

  end
end
