# Copyright (c) 2009-2012 VMware, Inc.

require 'uri'
require 'excon'
require "openssl"
require "base64"
require 'uri'

module Bosh::HwCloud

  class Cloud < Bosh::Cloud
    include Helpers

    # default maximum number of times to retry an AWS API call
    DEFAULT_MAX_RETRIES = 2
    METADATA_TIMEOUT    = 5 # in seconds
    DEVICE_POLL_TIMEOUT = 60 # in seconds

    attr_reader   :registry
    attr_reader   :options
    attr_accessor :logger

    ##
    # Initialize BOSH HwCloud CPI. The contents of sub-hashes are defined in the {file:README.md}
    # @param [Hash] options CPI options
    # @option options [Hash] aws AWS specific options
    # @option options [Hash] agent agent options
    # @option options [Hash] registry agent options

#by zxy
    def initialize(options)
      @options = options.dup.freeze
      validate_options

      @logger = Bosh::Clouds::Config.logger

      initialize_hwcloud
#      initialize_registry

      @metadata_lock = Mutex.new
    end

    ##
    # Reads current instance id from EC2 metadata. We are assuming
    # instance id cannot change while current process is running
    # and thus memoizing it.
    def current_vm_id
      @metadata_lock.synchronize do
        return @current_vm_id if @current_vm_id

        client = HTTPClient.new
        client.connect_timeout = METADATA_TIMEOUT
        # Using 169.254.169.254 is an EC2 convention for getting
        # instance metadata
        uri = "http://169.254.169.254/latest/meta-data/instance-id/"

        response = client.get(uri)
        unless response.status == 200
          cloud_error("Instance metadata endpoint returned " \
                      "HTTP #{response.status}")
        end

        @current_vm_id = response.body
      end

    rescue HTTPClient::TimeoutError
      cloud_error("Timed out reading instance metadata, " \
                  "please make sure CPI is running on EC2 instance")
    end
    
    ##
    # Generates an unique name
    #
    # @return [String] Unique name
    def generate_unique_name
      SecureRandom.uuid
    end
    
    ##
    # Create an EC2 instance and wait until it's in running state
    # @param [String] agent_id agent id associated with new VM
    # @param [String] stemcell_id AMI id of the stemcell used to
    #  create the new instance
    # @param [Hash] resource_pool resource pool specification
    # @param [Hash] network_spec network specification, if it contains
    #  security groups they must already exist
    # @param [optional, Array] disk_locality list of disks that
    #   might be attached to this instance in the future, can be
    #   used as a placement hint (i.e. instance will only be created
    #   if resource pool availability zone is the same as disk
    #   availability zone)
    # @param [optional, Hash] environment data to be merged into
    #   agent settings
    # @return [String] EC2 instance id of the new virtual machine

    def create_vm(agent_id, stemcell_id,
        resource_pool, network_spec, disk_locality = nil, environment = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do

        @logger.info('Creating new server...')
        server_name = "vm-#{generate_unique_name}"

        network_configurator = NetworkConfigurator.new(network_spec)
        nics = network_configurator.nics
        @logger.debug("Using NICs: `#{nics.join(', ')}'")

        security_groups_info = @qingcloudsdk.describe_security_groups() 
        qingcloud_security_groups = []
        security_groups_info["security_group_set"].each do |sg|
          qingcloud_security_groups << sg["security_group_id"]
        end

        security_groups = network_configurator.security_groups(@default_security_groups) 
        security_groups.each do |sg|
          cloud_error("Security group `#{sg}' not found") unless qingcloud_security_groups.include?(sg)
        end
        
        #check image 
        image = @qingcloudsdk.describe_images(stemcell_id)

        cloud_error("Image `#{stemcell_id}' not found") if image["total_count"] == 0
        @logger.debug("Using image: `#{stemcell_id}'")

        #check instance type
        instance_type = resource_pool['instance_type']
        instance_types = @qingcloudsdk.find_instance_types(qingcloud_region)
        cloud_error("instance_type `#{instance_type}' not found") unless instance_types.include?(instance_type)

        #check keypair
        keyname = resource_pool['key_name'] || @default_key_name
        keypair = @qingcloudsdk.describe_key_pairs(keyname)

        cloud_error("Key-pair `#{keyname}' not found") if keypair["total_count"] != 1
        @logger.debug("Using key-pair: `#{keypair["keypair_set"][0]["keypair_name"]}'")

        net_id = "vxnet-0"
        network_spec.each_pair do |name, network|
          network_type = network["type"] || "manual"
          if network_type == "dynamic"
            net_id = network["cloud_properties"]["net_id"] == nil ? "vxnet-0" : network["cloud_properties"]["net_id"]
          elsif network_type == "manual"
            static_ip = network["ip"]
            net_id = network["cloud_properties"]["net_id"] == nil ? "vxnet-0" : network["cloud_properties"]["net_id"]
            net_id = net_id + "|" + static_ip unless static_ip == nil
          end
        end

        user_data = Base64.encode64(user_data(server_name, network_spec, "ssh-rsa " + keypair["keypair_set"][0]["pub_key"]).to_json)
        server_params = {
          :instance_name => server_name,
          :image_id => stemcell_id,
          :instance_type => instance_type,
          :login_mode  => "keypair",
          :login_keypair => keyname,
          :vxnets => net_id,
          :security_group => security_groups[0],
          :user_data => user_data
        }

        server = @qingcloudsdk.run_instances(server_params)

        cloud_error("run_instances is failed, #{server["message"]}") if server["ret_code"] != 0
        @logger.info("Creating new server `#{server_name}'...")

        begin
          sleep(60)
          wait_resource(server["instances"][0], "running", method(:get_vm_status))
        rescue Bosh::Clouds::CloudError => e
          @logger.warn("Failed to create server: #{e.message}")
          @qingcloudsdk.terminate_instances(instance_info["instances"][0])
          raise Bosh::Clouds::VMCreationFailed.new(true)
        end

        #associate floationg ip
        @logger.info("Configuring network for server `#{server["instances"][0]}'...")
        network_configurator.configure(@qingcloudsdk, server)

        @logger.info("Updating settings for server `#{server["instances"][0]}'...")
        settings = initial_agent_settings(server_name, agent_id, network_spec, environment,
                                          flavor_has_ephemeral_disk?(instance_type))
        # @registry.update_settings(server["instances"][0], settings)
        @registry.update_settings(server_name, settings)
        server["instances"][0]
      end
    end

    ##
    # Delete Qing instance ("terminate" in Qing language) and wait until
    # it reports as terminated
    # @param [String] instance_id EC2 instance id
    def delete_vm(instance_id)
      with_thread_name("delete_vm(#{instance_id})") do
        logger.info("Deleting instance '#{instance_id}'")

        instance_info = @qingcloudsdk.describe_exist_instances(instance_id)
        if instance_info["total_count"] != 0 
          @qingcloudsdk.terminate_instances(instance_id)
          wait_resource(instance_id, "terminated", method(:get_vm_status))

          @logger.info("Deleting settings for server `#{instance_id}'/`#{instance_info["instance_set"][0]["instance_name"]}'...")
          @registry.delete_settings(instance_info["instance_set"][0]["instance_name"])
        else
          @logger.info("Server `#{instance_id}' not found. Skipping.")
        end
      end
    end

    ##
    # Reboot Qing instance
    # @param [String] instance_id Qing instance id
    def reboot_vm(instance_id)
      with_thread_name("reboot_vm(#{instance_id})") do
        instance_info = @qingcloudsdk.describe_exist_instances(instance_id)
        cloud_error("Server `#{instance_id}' not found") if instance_info["total_count"] == 0

        @logger.info("Restart server `#{instance_id}'...")
        ret = @qingcloudsdk.restart_instances(instance_id)
        wait_resource(instance_id, "running", method(:get_vm_status))
      end
    end

    ##
    # Has Qing instance
    # @param [String] instance_id Qing instance id
    def has_vm?(instance_id)
      with_thread_name("has_vm?(#{instance_id})") do
        ret = @qingcloudsdk.describe_instances(instance_id)
        ret["total_count"] != 0  &&  ![:terminated, :ceased].include?(ret["instance_set"][0]["status"])
      end
    end

    ##
    # Creates a new  volume
    # @param [Integer] size disk size in MiB
    # @param [optional, String] volume name
    # @param [optional, Integer] volume count
    # @return [String] created  volume id
    def create_disk(size, server_id = nil)
      with_thread_name("create_disk(#{size}, #{server_id})") do
        validate_disk_size(size)

        volume_params = {
          :size => (size / 1024.0).ceil,
          :name => "volume-#{generate_unique_name}",
          :count => 1          
        }

        logger.info("Creating new volume '#{volume_params[:name]}'")
        volume_info = @qingcloudsdk.create_volumes(volume_params)

        wait_resource(volume_info["volumes"][0], "available", method(:get_disk_status))
        volume_info["volumes"][0]
      end
    end

    def validate_disk_size(size)
      raise ArgumentError, "disk size needs to be an integer" unless size.kind_of?(Integer)
      raise ArgumentError, "disk size needs to be Divisible by 10" unless (size % 10 == 0)

      cloud_error("HwCloud CPI minimum disk size is 10  GiB") if size < 1024 * 10
      cloud_error("HwCloud CPI maximum disk size is 500 GiB") if size > 1024 * 500
    end

    ##
    # Delete hwcloud volume
    # @param [String] disk_id hwcloud volume id
    # @raise [Bosh::Clouds::CloudError] if disk is not in available state
    def delete_disk(disk_id)
      with_thread_name("delete_disk(#{disk_id})") do
        @logger.info("Deleting volume `#{disk_id}'...")
        volume_info = @qingcloudsdk.describe_volumes(disk_id)
        state = volume_info["volume_set"][0]["status"]
        if volume_info["total_count"] != 0  && ![:deleted, :ceased].include?(state)

          if  state != "available"
            cloud_error("Cannot delete volume `#{disk_id}', state is #{state}")
          end

          ret = @qingcloudsdk.delete_volumes(disk_id)
          wait_resource(disk_id, "deleted", method(:get_disk_status))
        else
          @logger.info("Volume `#{disk_id}' not found. Skipping.")
        end
      end

    end

    # Attach an  volume to an instance
    # @param [String] instance_id EC2 instance id of the virtual machine to attach the disk to
    # @param [String] disk_id EBS volume id of the disk to attach
    def attach_disk(instance_id, disk_id)
      with_thread_name("attach_disk(#{instance_id}, #{disk_id})") do
        instance = has_vm?(instance_id)
        cloud_error("Instance `#{instance_id}' not found") unless instance

        ret_info = get_disks(disk_id)
        cloud_error("Volume `#{disk_id}' not found") if ret_info["total_count"] == 0

        disk_name=  ret_info["volume_set"][0]["volume_name"]
        disk_status = ret_info["volume_set"][0]["status"]
        cloud_error('Disk is in use') if disk_status != "available"

        device_name = attach_volume(disk_id, instance_id)

        update_agent_settings(instance_id) do |settings|
          settings["disks"] ||= {}
          settings["disks"]["persistent"] ||= {}
          settings["disks"]["persistent"][disk_id] = device_name
        end

        logger.info("Attached `#{disk_id}' to `#{instance_id}'")

        disk_name
      end
    end


    ##
    # Attaches an HwCloud volume to an OpenStack server
    #
    # @param disk id
    # @param instance id
    # @return [String] Device name
    def attach_volume(disk_id, instance_id)
      @logger.info("Attaching volume `#{disk_id}' to server `#{instance_id}'...")
      volume_info = @qingcloudsdk.describe_volumes(disk_id)
      volume_id = volume_info["volume_set"][0]["volume_id"]

      if volume_info["volume_set"][0]["status"] != "available"
        instance_disk_id = volume_info["volume_set"][0]["instance"]["instance_id"]
        cloud_error("Instance `#{instance_id}' is not attach to #{disk_id}") unless instance_disk_id == instance_id
      end

      devices_name = []
      update_agent_settings(instance_id) do |settings|
        if settings["disks"] != nil && settings["disks"]["persistent"] != nil
          settings["disks"]["persistent"].each_pair do |id, name|
            devices_name << name
          end
        end
      end

      if devices_name.empty?
        device_name = select_device_name(devices_name)
        attachment = @qingcloudsdk.attach_volumes(disk_id, instance_id)
        wait_resource(disk_id, "in-use", method(:get_disk_status))
      else

        update_agent_settings(instance_id) do |settings|
          if settings["disks"] != nil && settings["disks"]["persistent"] != nil
            settings["disks"]["persistent"].each_pair do |id, name|
              device_name = name if id == volume_id
            end
          end
        end

        @logger.info("Volume `#{disk_id}' is already attached to server `#{instance_id}' in `#{device_name}'. Skipping.")
      end

      device_name
    end

    ##
    # Select the first available device name
    #
    # @param [Array] volume_attachments Volume attachments
    # @param [String] first_device_name_letter First available letter for device names
    # @return [String] First available device name or nil is none is available
    def select_device_name(devices)
      ('c'..'z').each do |char|
        # Some kernels remap device names (from sd* to vd* or xvd*).
        device_name = "/dev/sd#{char}"
        # Bosh Agent will lookup for the proper device name if we set it initially to sd*.
        return device_name unless  !devices.empty? && devices.include(device_name)
        @logger.warn("`/dev/sd#{char}' is already taken")
      end

      nil
    end

    # Detach an EBS volume from an EC2 instance
    # @param [String] instance_id EC2 instance id of the virtual machine to detach the disk from
    # @param [String] disk_id EBS volume id of the disk to detach
    def detach_disk(instance_id, disk_id)
      with_thread_name("detach_disk(#{instance_id}, #{disk_id})") do
        instance = has_vm?(instance_id)
        cloud_error("Instance `#{instance_id}' not found") unless instance

        ret_info = get_disks(disk_id)
        cloud_error("Volume `#{disk_id}' not found") unless ret_info["total_count"] == 1

        disk_instance_id = ret_info["volume_set"][0]["instance"]["instance_id"]
        if disk_instance_id == instance_id
          detachment = @qingcloudsdk.detach_volumes(disk_id, instance_id)

          wait_resource(disk_id, "available", method(:get_disk_status))

          update_agent_settings(instance_id) do |settings|
           settings["disks"] ||= {}
           settings["disks"]["persistent"] ||= {}
           settings["disks"]["persistent"].delete(disk_id)
          end

          logger.info("Detached `#{disk_id}' from `#{instance_id}'")
        else
          @logger.info("Disk `#{disk_id}' is not attached to server `#{instance_id}'. Skipping.")
        end
      end
    end


#by zxy
    def get_disks(disk_id)
      with_thread_name("get_disks(#{disk_id})") do
      
      options={
    :'VolumeId[0]'          => "#{disk_id}",
    :AvailabilityZone  =>  'b451c1ea3c8d4af89d03e5cacf1e4276'
      }
        ret = @hwcloudsdk.describe_volumes(options)
      end
    end


    def get_disk_status(volume_id)
      with_thread_name("get_disk_status(#{volume_id})") do
        ret_info = @qingcloudsdk.describe_volumes(volume_id)
        return ret_info["volume_set"][0]["status"] 
      end
    end

    def get_vm_status(instance_id)
      with_thread_name("get_vm_status(#{instance_id})") do
        ret = @qingcloudsdk.describe_instances(instance_id)
        status = ""
        if(ret["total_count"] == 1)
          status = ret["instance_set"][0]["status"]
        end
        status
      end
    end

    # Take snapshot of disk
    # @param [String] disk_id disk id of the disk to take the snapshot of
    # @return [String] snapshot id
    def snapshot_disk(disk_id, metadata)
      with_thread_name("snapshot_disk(#{disk_id})") do
        
        volume_info = @qingcloudsdk.describe_available_volumes(disk_id)
        cloud_error("Volume `#{disk_id}' not found") if volume_info["total_count"] == 0

        snapshot_name = "snapshot-#{generate_unique_name}"
        @logger.info("Creating new snapshot for volume `#{disk_id}'...")
        ret = @qingcloudsdk.create_snapshots(disk_id, snapshot_name)

        @logger.info("Creating new snapshot `#{snapshot_name}' for volume `#{disk_id}'...")        
        wait_resource(ret["snapshots"][0], "available", method(:get_snapshot_status))
        
        ret["snapshots"][0]
      end
    end

    # Delete a disk snapshot
    # @param [String] snapshot_id snapshot id to delete
    def delete_snapshot(snapshot_id)
      with_thread_name("delete_snapshot(#{snapshot_id})") do
        @logger.info("Deleting snapshot `#{snapshot_id}'...")
        snapshot_info = @qingcloudsdk.describe_available_snapshot(snapshot_id)
        
        if snapshot_info["total_count"] == 1

            ret = @qingcloudsdk.delete_snapshots(snapshot_id)
            snapshot_after_delete = @qingcloudsdk.describe_snapshot(snapshot_id)

            wait_resource(snapshot_after_delete["snapshot_set"][0], "ceased", method(:get_snapshot_status))

        else
          logger.info("snapshot `#{snapshot_id}' not found. Skipping.")
        end
      end
    end

    def get_snapshot_status(snapshot_id)
      with_thread_name("get_snapshot(#{snapshot_id})") do
        ret = @qingcloudsdk.describe_snapshot(snapshot_id)
        return ret["snapshot_set"][0]["status"]
      end
    end

    # Configure network for an EC2 instance
    # @param [String] instance_id EC2 instance id
    # @param [Hash] network_spec network properties
    # @raise [Bosh::Clouds:NotSupported] if there's a network change that requires the recreation of the VM
    def configure_networks(instance_id, network_spec)
      with_thread_name("configure_networks(#{instance_id}, ...)") do
        logger.info("Configuring '#{instance_id}' to use new network settings: #{network_spec.pretty_inspect}")

        # instance = @ec2.instances[instance_id]

        instance_info = @qingcloudsdk.describe_instances(instance_id)

        if instance_info == nil || instance_info["total_count"] == 0
          cloud_error("Can not find the Instance")
        end

        network_configurator = NetworkConfigurator.new(network_spec)

        # compare_security_groups(instance, network_spec)

        # compare_private_ip_addresses(instance, network_configurator.private_ip)

        # network_configurator.configure(@ec2, instance)

        network_configurator.configure(@qingcloudsdk, instance_info)

        update_agent_settings(instance_id) do |settings|
          settings["networks"] = network_spec
        end
      end
    end

    # If the security groups change, we need to recreate the VM
    # as you can't change the security group of a running instance,
    # we need to send the InstanceUpdater a request to do it for us
    def compare_security_groups(instance, network_spec)
      actual_group_names = instance.security_groups.collect { |sg| sg.name }
      specified_group_names = extract_security_group_names(network_spec)
      if specified_group_names.empty?
        new_group_names = Array(qingcloud_properties["default_security_groups"])
      else
        new_group_names = specified_group_names
      end

      unless actual_group_names.sort == new_group_names.sort
        raise Bosh::Clouds::NotSupported,
              "security groups change requires VM recreation: %s to %s" %
                  [actual_group_names.join(", "), new_group_names.join(", ")]
      end
    end

    ##
    # Compares actual instance private IP addresses with the IP address specified at the network spec
    #
    # @param [AWS::EC2::Instance] instance EC2 instance
    # @param [String] specified_ip_address IP address specified at the network spec (if Manual Network)
    # @return [void]
    # @raise [Bosh::Clouds:NotSupported] If the IP address change, we need to recreate the VM as you can't
    # change the IP address of a running server, so we need to send the InstanceUpdater a request to do it for us
    def compare_private_ip_addresses(instance, specified_ip_address)
      actual_ip_address = instance.private_ip_address

      unless specified_ip_address.nil? || actual_ip_address == specified_ip_address
        raise Bosh::Clouds::NotSupported,
              "IP address change requires VM recreation: %s to %s" %
              [actual_ip_address, specified_ip_address]
      end
    end

    ##
    # Creates a new stemcell using stemcell image.
    # This method can only be run on an EC2 instance, as image creation
    # involves creating and mounting new EBS volume as local block device.
    # @param [String] image_path local filesystem path to a stemcell image
    # @param [Hash] cloud_properties AWS-specific stemcell properties
    # @option cloud_properties [String] kernel_id
    #   AKI, auto-selected based on the region, unless specified
    # @option cloud_properties [String] root_device_name
    #   block device path (e.g. /dev/sda1), provided by the stemcell manifest, unless specified
    # @option cloud_properties [String] architecture
    #   instruction set architecture (e.g. x86_64), provided by the stemcell manifest,
    #   unless specified
    # @option cloud_properties [String] disk (2048)
    #   root disk size
    # @return [String] EC2 AMI name of the stemcell
    def create_stemcell(image_path, stemcell_properties)
      with_thread_name("create_stemcell(#{image_path}...)") do
        
        stemcell_info = @qingcloudsdk.describe_images_by_name("qingcloud_stemcell")
        if stemcell_info["total_count"] == 0
          raise "can't find the stemcell"
        end

        image_id = stemcell_info["image_set"][0]["image_id"]
      end
    end

    # Delete a stemcell and the accompanying snapshots
    # @param [String] stemcell_id  name of the stemcell to be deleted
    def delete_stemcell(stemcell_id)
      with_thread_name("delete_stemcell(#{stemcell_id})") do
        options={
            :'Filter[1].Name' => "#{stemcell_id}",
            :'Filter[1].Value[0]' => 'gc-test',
        }

        image = @hwcloudsdk.describe_images_by_name(stemcell_id)
        puts image

        if image[:total_count] != 0
          puts "haha"
          options={
              :'ImageFolderName[0]' => "#{stemcell_id}",
          }
          ret = @hwcloudsdk.delete_images(options)
          @logger.info("Stemcell `#{stemcell_id}' is now deleted")
        else
          puts "555"
          @logger.info("Stemcell `#{stemcell_id}' not found. Skipping.")
        end
      end
    end

    # Add tags to an instance. In addition to the suplied tags,
    # it adds a 'Name' tag as it is shown in the AWS console.
    # @param [String] vm vm id that was once returned by {#create_vm}
    # @param [Hash] metadata metadata key/value pairs
    # @return [void]
    def set_vm_metadata(instance_id, metadata)
      # with_thread_name("set_vm_metadata(#{instance_id}, ...)") do
      #     server = @qingcloudsdk.describe_instances(instance_id)
      #     cloud_error("Server `#{instance_id}' not found") unless server

      #     metadata.each do |name, value|
      #       TagManager.tag(server.to_json, name, value)
      #     end
      # end
    end

    def find_ebs_device(sd_name)
      xvd_name = sd_name.gsub(/^\/dev\/sd/, "/dev/xvd")

      DEVICE_POLL_TIMEOUT.times do
        if File.blockdev?(sd_name)
          return sd_name
        elsif File.blockdev?(xvd_name)
          return xvd_name
        end
        sleep(1)
      end

      cloud_error("Cannot find EBS volume on current instance")
    end


    private

    attr_reader :az_selector
    attr_reader :region

    def agent_properties
      @agent_properties ||= options.fetch('agent', {})
    end

    def qingcloud_properties
      @qingcloud_properties ||= options.fetch('hwcloud')
    end

    # by zxy
    def hwcloud_properties
      @hwcloud_properties ||= options.fetch('hwcloud')
    end

    def qingcloud_region
      @qingcloud_region ||= qingcloud_properties.fetch('region', nil)
    end

    def fast_path_delete?
      qingcloud_properties.fetch('fast_path_delete', false)
    end

    def initialize_qingcloud
      qingcloud_logger = logger
      qingcloud_params = {
          region:            qingcloud_properties['region'],
          access_key_id:     qingcloud_properties['access_key_id'],
          secret_access_key: qingcloud_properties['secret_access_key'],
          #ec2_endpoint:      qingcloud_properties['ec2_endpoint'] || default_ec2_endpoint,
          #elb_endpoint:      aws_properties['elb_endpoint'] || default_elb_endpoint,
          #max_retries:       aws_properties['max_retries']  || DEFAULT_MAX_RETRIES ,
          logger:             qingcloud_logger
      }

      @default_key_name = qingcloud_properties["default_key_name"]
      @default_security_groups = qingcloud_properties["default_security_groups"]
      @wait_resource_poll_interval = qingcloud_properties["wait_resource_poll_interval"] || 5
      @qingcloudsdk = QingCloudSDK.new(qingcloud_params) 

    end
    #by zxy
    def initialize_hwcloud
      hwcloud_logger = logger
      hwcloud_params = {
          :url =>            hwcloud_properties['url'],
          :HWSAccessKeyId =>            hwcloud_properties['HWSAccessKeyId'],
          :Version=>     hwcloud_properties['Version'],
          :SignatureMethod=> hwcloud_properties['SignatureMethod'],
          :SignatureNonce=> hwcloud_properties['SignatureNonce'],
          :SignatureVersion=> hwcloud_properties['SignatureVersion'],
          :RegionName=> hwcloud_properties['RegionName'],
          :Key=> hwcloud_properties['Key'],
      }


      @wait_resource_poll_interval = hwcloud_properties["wait_resource_poll_interval"] || 5
     # require "huaweicloud"
      @hwcloudsdk = HwCloud::HwCloudSdk.new(hwcloud_params)

    end

    def initialize_registry
      registry_properties = options.fetch('registry')
      registry_endpoint   = registry_properties.fetch('endpoint')
      registry_user       = registry_properties.fetch('user')
      registry_password   = registry_properties.fetch('password')

      # Registry updates are not really atomic in relation to
      # EC2 API calls, so they might get out of sync. Cloudcheck
      # is supposed to fix that.
      @registry = Bosh::Registry::Client.new(registry_endpoint,
                                             registry_user,
                                             registry_password)
    end

    def update_agent_settings(instance_id)
      unless block_given?
        raise ArgumentError, "block is not provided"
      end

      instance_info = @qingcloudsdk.describe_instances(instance_id)
      if instance_info["total_count"] != 0 
        # settings = registry.read_settings(instance_id)
        settings = registry.read_settings(instance_info["instance_set"][0]["instance_name"])
        yield settings
        registry.update_settings(instance_info["instance_set"][0]["instance_name"], settings)
      else
        @logger.info("Server `#{instance_id}' not found. Skipping.")
      end
    end

    ##
    # Prepare server user data
    #
    # @param [String] server_name server name
    # @param [Hash] network_spec network specification
    # @return [Hash] server user data
    def user_data(server_name, network_spec, public_key = nil)
      data = {}

      data['registry'] = { 'endpoint' => @registry.endpoint }
      data['server'] = { 'name' => server_name }
      data['openssh'] = { 'public_key' => public_key } if public_key

      with_dns(network_spec) do |servers|
        data['dns'] = { 'nameserver' => servers }
      end

      data
    end

    ##
    # Extract dns server list from network spec and yield the the list
    #
    # @param [Hash] network_spec network specification for instance
    # @yield [Array]
    def with_dns(network_spec)
      network_spec.each_value do |properties|
        if properties.has_key?('dns') && !properties['dns'].nil?
          yield properties['dns']
          return
        end
      end
    end

    ##
    # Checks if options passed to CPI are valid and can actually
    # be used to create all required data structures etc.
    #

#by zxy
    def validate_options
      required_keys = {
          "hwcloud" => ["url", "HWSAccessKeyId", "Version", "SignatureMethod","SignatureNonce", "SignatureVersion", "RegionName", "Key"],
          #"registry" => ["endpoint", "user", "password"],
      }

      missing_keys = []

      required_keys.each_pair do |key, values|
        values.each do |value|
          if (!options.has_key?(key) || !options[key].has_key?(value))
            missing_keys << "#{key}:#{value}"
          end
        end
      end

      raise ArgumentError, "missing configuration parameters > #{missing_keys.join(', ')}" unless missing_keys.empty?
    end
    ##
    # Checks if the HwCloud instance type has ephemeral disk
    #
    # @param  flavor
    # @return [Boolean] true if flavor has ephemeral disk, false otherwise
    def flavor_has_ephemeral_disk?(flavor)
    # flavor.ephemeral.nil? || flavor.ephemeral.to_i <= 0 ? false : true
      false
    end

    ##
    # Generates initial agent settings. These settings will be read by Bosh Agent from Bosh Registry on a target
    # server. Disk conventions in Bosh Agent for OpenStack are:
    # - system disk: /dev/sda
    # - ephemeral disk: /dev/sdb
    # - persistent disks: /dev/sdc through /dev/sdz
    # As some kernels remap device names (from sd* to vd* or xvd*), Bosh Agent will lookup for the proper device name
    #
    # @param [String] server_name Name of the OpenStack server (will be picked
    #   up by agent to fetch registry settings)
    # @param [String] agent_id Agent id (will be picked up by agent to
    #   assume its identity
    # @param [Hash] network_spec Agent network spec
    # @param [Hash] environment Environment settings
    # @param [Boolean] has_ephemeral Has Ephemeral disk?
    # @return [Hash] Agent settings
    def initial_agent_settings(server_name, agent_id, network_spec, environment, has_ephemeral)
      settings = {
          'vm' => {
              'name' => server_name
          },
          'agent_id' => agent_id,
          'networks' => network_spec,
          'disks' => {
              'system' => '/dev/sda',
              'persistent' => {}
          }
      }

      settings['disks']['ephemeral'] = has_ephemeral ? '/dev/sdb' : nil
      settings['env'] = environment if environment
      settings.merge(agent_properties)
    end

  end
end

