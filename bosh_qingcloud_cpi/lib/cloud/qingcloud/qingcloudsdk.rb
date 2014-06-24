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

    def describe_volumes(vm_id)
      volumes = []
      volumes << vm_id
      ret =  @conn.describe_volumes(volumes,
          instance_id = [],
          status = [],
          search_word = [],
          verbose = 0,
          offset = 0,
          limit = 50)
      ret_info = RubyPython::Conversion.ptorDict(ret.pObject.pointer)
      ret_info
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
      ret = @conn.describe_images(images,
                                  os_family = [],
                                  processor_type = [],
                                  status = [],
                                  visibility = [],
                                  provider = [],
                                  verbose = 0,
                                  search_word = [],
                                  offset = 0,
                                  limit = 0)
      ret_info = RubyPython::Conversion.ptorDict(ret.pObject.pointer)
      ret_info				  
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
    
    def run_instances(image_id, instance_name, instance_type, vxnet, security_group, login_mode, login_keypair)
      image = ""
      image << image_id
      name = ""
      name << instance_name
      type = ""
      type << instance_type
      vxnet_id = []
      vxnet_id << vxnet
      securityGroup = ""
      securityGroup << security_group
      loginMode = ""
      loginMode << login_mode
      loginKeypair = ""
      loginKeypair << login_keypair
      ret = @conn.run_instances(image,
                            type,
                            cpu = nil,
                            memory = nil,
                            count = 1,
                            name,
                            vxnet_id,
                            securityGroup,
                            loginMode,
                            loginKeypair,
                            login_passwd = "C1oudc0w",
                            need_newsid = 0)  
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
  end
end
