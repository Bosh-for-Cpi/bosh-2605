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
      ret = @conn.describe_instances(instances,
                                      image_id = [],
                                      instance_type = [],
                                      status = [],
                                      search_word = [],
                                      verbose = 0,
                                      offset = 0,
                                      limit = 0)
      return RubyPython::Conversion.ptorDict(ret.pObject.pointer)
    end

    def describe_exist_instances(instance_id)
      instances = []
      instances << instance_id 
      ret = @conn.describe_instances(instances,
                                      image_id = [],
                                      instance_type = [],
                                      status = ["pending", "running", "stopped", "suspended"],
                                      search_word = [],
                                      verbose = 0,
                                      offset = 0,
                                      limit = 0)
      return RubyPython::Conversion.ptorDict(ret.pObject.pointer)
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
      ret = @conn.describe_volumes(volumes,
                                    instance_id = [],
                                    status = [],
                                    search_word = [],
                                    verbose = 0,
                                    offset = 0,
                                    limit = 0)
      return RubyPython::Conversion.ptorDict(ret.pObject.pointer)
    end

    def describe_available_volumes(volume_id)
      volumes = []
      volumes << volume_id
      ret = @conn.describe_volumes(volumes,
                                    instance_id = [],
                                    status = ["available"],
                                    search_word = [],
                                    verbose = 0,
                                    offset = 0,
                                    limit = 0)
      return RubyPython::Conversion.ptorDict(ret.pObject.pointer)
    end

    def describe_volumes_by_instance_id(instance_id)
      ret = @conn.describe_volumes(volumes = [],
                                    instance_id,
                                    status = ["in-use"],
                                    search_word = [],
                                    verbose = 0,
                                    offset = 0,
                                    limit = 0)
      return RubyPython::Conversion.ptorDict(ret.pObject.pointer)
    end

    def create_volumes(volume_params)
      size = volume_params[:size]
      volume_name = volume_params[:name]
      count = volume_params[:count]
      ret = @conn.create_volumes(size, volume_name, count)
      return RubyPython::Conversion.ptorDict(ret.pObject.pointer)
    end

    # Attach one or more volumes to same instance
    # @param volumes : an array including IDs of the volumes you want to attach.
    # @param instance : the ID of instance the volumes will be attached to.
    def attach_volumes(volume_id, instance_id)
      volumes = []
      volumes << volume_id
      return @conn.attach_volumes(volumes, instance_id)
    end

    def detach_volumes(volume_id, instance_id)
      volumes = []
      volumes << volume_id    
      return @conn.detach_volumes(volumes, instance_id)
    end

    def describe_images(stemcell_id)
      images = []
      images << stemcell_id
      ret = @conn.describe_images(images,
                                  os_family = [],
                                  processor_type = [],
                                  status = ["available"],
                                  visibility = [],
                                  provider = [],
                                  verbose = 0,
                                  search_word = [],
                                  offset = 0,
                                  limit = 0)
      return RubyPython::Conversion.ptorDict(ret.pObject.pointer)
    end

    def describe_images_by_name(stemcell_name)
      search_word = stemcell_name || []
      ret = @conn.describe_images(images = [],
                                  os_family = [],
                                  processor_type = [],
                                  status = ["available"],
                                  visibility = [],
                                  provider = [],
                                  verbose = 0,
                                  search_word,
                                  offset = 0,
                                  limit = 0)
      return RubyPython::Conversion.ptorDict(ret.pObject.pointer)
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
      ret = @conn.create_snapshots(resources_id, snapshot_name, is_full=1)
      return RubyPython::Conversion.ptorDict(ret.pObject.pointer)
    end

    def delete_snapshots(snapshots)
      snapshots_id = []
      snapshots_id << snapshots
      return @conn.delete_snapshots(snapshots_id)
    end

    def describe_snapshot(snapshot_id)
      snapshots = []
      snapshots << snapshot_id
      ret = @conn.describe_snapshots(snapshots,
                                      resource_id = [],
                                      snapshot_type = 1,
                                      root_id = [],
                                      status = [],
                                      verbose = 0,
                                      search_word = [],
                                      offset = 0,
                                      limit = 0)
      return RubyPython::Conversion.ptorDict(ret.pObject.pointer)
    end

    def describe_available_snapshot(snapshot_id)
      snapshots = []
      snapshots << snapshot_id
      status = []
      status << snapshot_status
      ret = @conn.describe_snapshots(snapshots,
                                      resource_id = [],
                                      snapshot_type = 1,
                                      root_id = [],
                                      status = ["available"],
                                      verbose = 0,
                                      search_word = [],
                                      offset = 0,
                                      limit = 0)
      return RubyPython::Conversion.ptorDict(ret.pObject.pointer)
    end

    def describe_security_groups()
      ret = @conn.describe_security_groups(security_groups = [],
                                           security_group_name = "",
                                           search_word = [],
                                           verbose = 0,
                                           offset = 0,
                                           limit = 0)
      ret_info = RubyPython::Conversion.ptorDict(ret.pObject.pointer)
      ret_info
    end

    def describe_key_pairs(keyname)
      ret = @conn.describe_key_pairs(keypairs = [],
                                 encrypt_method = [],
                                 keyname,
                                 verbose = 0,
                                 offset = 0,
                                 limit = 0)
      ret_info = RubyPython::Conversion.ptorDict(ret.pObject.pointer)
      ret_info
    end

    def run_instances(server_params)
      image_id = server_params[:image_id]
      instance_name = server_params[:instance_name]
      instance_type = server_params[:instance_type]
      loginMode = server_params[:login_mode]
      login_keypair = server_params[:login_keypair]
      vxnets = []
      vxnets << server_params[:vxnets]
      security_group = server_params[:security_group]
      need_userdata = server_params[:user_data] != nil ? 1 : 0
      userdata_value = server_params[:user_data]
      ret = @conn.run_instances(image_id,
                                instance_type,
                                cpu = nil,
                                memory = nil,
                                count = 1,
                                instance_name,
                                vxnets,
                                security_group,
                                loginMode,
                                login_keypair,
                                login_passwd = "C1oudc0w",
                                need_newsid = 0,
                                volumes = [],
                                need_userdata,
                                userdata_type = "plain",
                                userdata_value)
      ret_info = RubyPython::Conversion.ptorDict(ret.pObject.pointer)
      ret_info
    end

    def describe_eips(instance_id,ip)
      search_word = (ip == nil) ? [] : ip
      instances = (instance_id == nil) ? [] : instance_id
      ret = @conn.describe_eips(eips = [],
                                status = [],
                                instances,
                                search_word,
                                offset = 0,
                                limit = 0)
      ret_info = RubyPython::Conversion.ptorDict(ret.pObject.pointer)
      ret_info
    end

    def associate_eip(eip, instance_id)
      ret = @conn.associate_eip(eip,
                            instance_id)
      ret_info = RubyPython::Conversion.ptorDict(ret.pObject.pointer)
      ret_info
    end

    def dissociate_eips(eip)
      eips = []
      eips << eip
      ret = @conn.dissociate_eips(eips)
      ret_info = RubyPython::Conversion.ptorDict(ret.pObject.pointer)
      ret_info
    end

    def describe_vxnets(network_id)
      vxnets = []
      vxnets << network_id
      ret = @conn.describe_vxnets(vxnets,
                                  search_word = [],
                                  verbose = 0,
                                  limit = 0,
                                  offset = 0)
      ret_info = RubyPython::Conversion.ptorDict(ret.pObject.pointer)
      ret_info
    end

    def add_router_statics(router,statics)
      ret = @conn.add_router_statics(router,
                                     statics)
      ret_info = RubyPython::Conversion.ptorDict(ret.pObject.pointer)
      ret_info
    end
    def update_routers(router)
      routers = []
      routers << router
      ret = @conn.update_routers(routers)
      ret_info = RubyPython::Conversion.ptorDict(ret.pObject.pointer)
      ret_info
    end

    def describe_routers(router)
      routers = []
      routers << router
      ret = @conn.describe_routers(routers,
                                   vxnet = [],
                                   status = ["active"],
                                   verbose = 0,
                                   search_word = [],
                                   limit = 0,
                                   offset = 0)
      ret_info = RubyPython::Conversion.ptorDict(ret.pObject.pointer)
      ret_info
    end

    def find_instance_types(region)
      instance_types = Hash.new()
      instance_types["gd1"] = ["c1m1", "c1m2", "c1m4", "c2m2", "c2m4", "c2m8", "c4m4", "c4m4", "c4m16"]
      instance_types["pek1"] = ["small_b", "small_c", "medium_a", "medium_b", "medium_c", "large_a", "large_b", "large_c"]

      return instance_types[region]
    end

  end
end
