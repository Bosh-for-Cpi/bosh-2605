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
    
  def create_vm(agent_id, stemcell_id, resource_pool, network_spec, disk_locality = nil, environment = nil)
    with_thread_name("create_vm(#{agent_id}, ...)") do 
      @logger.info('Creating new server...')
      server_name = "vm-#{generate_unique_name}"
    
      #network
      network_configurator = NetworkConfigurator.new(network_spec)
      security_groups = network_configurator.security_groups(nil)
      @logger.debug("Using security groups: `#{security_groups.join(', ')}'")     


      #check image exists
      image_options = {
            :'Filter[0].Name' => 'imageID',
            :'Filter[0].Value[0]' => "#{stemcell_id}",
      }
      image = @hwcloudsdk.describe_images_by_name(image_options)
      cloud_error("Image `#{stemcell_id}' not found") if image["imageSet"]["imageSet"].empty?
      @logger.debug("Using image: `#{stemcell_id}'")

      #check instnce_type
      instance_type = resource_pool['instance_type']
      @logger.debug("Using instance type: `#{instance_type}'")

      #link_type not need
      #link_type = resource_pool['link_type']
      #@logger.debug("Using link_type: `#{link_type}'")

      #check keypair
      keyname = resource_pool['key_name'] || @default_key_name
      key_options = { 
        'KeyName[0]'.to_sym => keyname
      }
      keypair = @hwcloudsdk.describe_key_pairs(key_options)
      cloud_error("Key-pair `#{keyname}' not found") unless keypair['keypairsSet']
      #@logger.debug("Using key-pair: ${keyname}")

      server_options = {
        'InstanceType'.to_sym => instance_type,
        'KeyName'.to_sym      => keyname,
        'ImageId'.to_sym      => stemcell_id,
        'MinCount'.to_sym     => 1,
        'MaxCount'.to_sym     => 1,
        'AvailabilityZone'.to_sym  => @availabilityzone,
        'SecurityGroupId'.to_sym   => security_groups[0] 
      } 

      ret = @hwcloudsdk.run_instances(server_options)
      instance_id = ret['instanceId']
    
      #wait running
      wait_resource(instance_id, "running", method(:get_vm_status))

      #acquire vm info
      options={}
      options = {
        'InstanceId[0]'.to_sym => instance_id
      }
      instance_info = @hwcloudsdk.describe_instances(options)

      #bind vip , need to modify 
      network_configurator.configure(@hwcloudsdk, instance_info)

      settings = initial_agent_settings(server_name, agent_id, network_spec, environment,
                                          flavor_has_ephemeral_disk?(instance_type))
      @registry.update_settings(['instancesSet']['instancesSet'][0]['instanceName'], settings)

      return instance_id

    end
  end
     

    def delete_vm(instance_id)
      with_thread_name("delete_vm(#{instance_id})") do
        logger.info("Deleting instance '#{instance_id}'")

        if has_vm?(instance_id)
          @logger.info("Deleting settings for server #{instance_id}")
          options = {'InstanceId[0]'.to_sym => instance_id}
          @hwcloudsdk.terminate_instances(options)
          @registry.delete_settings(instance_id)
        else
          @logger.info("Server `#{instance_id}' not found. Skipping.")
        end
      end
    end

    def reboot_vm(instance_id)
      with_thread_name("reboot_vm(#{instance_id})") do
        cloud_error("Server `#{instance_id}' not found") if !has_vm?(instance_id)

        @logger.info("Restart server `#{instance_id}'...")

        options = {'InstanceId[0]'.to_sym => instance_id}
        @hwcloudsdk.reboot_instances(options)
        wait_resource(instance_id, "running", method(:get_vm_status))
      end
    end

    def has_vm?(instance_id)
      with_thread_name("has_vm?(#{instance_id})") do
        options = {'InstanceId[0]'.to_sym => instance_id}
        instance = @hwcloudsdk.describe_instances(options)
        instance['instancesSet']
      end
    end

    def get_vm_status(instance_id)
      with_thread_name("get_vm_status(#{instance_id})") do
        options = {'InstanceId[0]'.to_sym => instance_id}
        instance = @hwcloudsdk.describe_instances(options)
        return instance['instancesSet']['instancesSet'][0]['instanceState']['name']
      end
    end

    ##
    # Creates a new  volume
    # @param [Integer] size disk size in MiB
    # @param [optional, String] volume name
    # @param [optional, Integer] volume count
    # @return [String] created  volume id
    def create_disk(size, instance_id = nil)
      with_thread_name("create_disk(#{size}, #{instance_id})") do
        validate_disk_size(size)

        volume_params = {
          :Size => (size / 1024.0).ceil,
          :name => "volume-#{generate_unique_name}",
          :AvailabilityZone => 'b451c1ea3c8d4af89d03e5cacf1e4276'
        }

        logger.info("Creating new volume '#{volume_params[:name]}'")
        volume_info = @hwcloudsdk.create_volume(volume_params)
        cloud_error("HwCloud CPI Create Volume Failed") unless /vol-[A-Za-z0-9]{8}/.match(volume_info["volumeId"])     
        wait_resource(volume_info["volumeId"], "available", method(:get_disk_status))
        puts volume_info["volumeId"]

        volume_info["volumeId"]
      end
    end

    def validate_disk_size(size)
      raise ArgumentError, "disk size needs to be an integer" unless size.kind_of?(Integer)

      cloud_error("HwCloud CPI minimum disk size is 1  GiB") if size < 1024
      cloud_error("HwCloud CPI maximum disk size is 1000 GiB") if size > 1024 * 1000
    end

    ##
    # Delete hwcloud volume
    # @param [String] disk_id hwcloud volume id
    # @raise [Bosh::Clouds::CloudError] if disk is not in available state
    def delete_disk(disk_id)
      with_thread_name("delete_disk(#{disk_id})") do
        @logger.info("Deleting volume `#{disk_id}'...")

        state = get_disk_status(disk_id)
        if state  != "noexist"
          cloud_error("Cannot delete volume `#{disk_id}', state is #{state}") unless state == 'available'

          options={:'VolumeId[0]' => "#{disk_id}"}
          ret = @hwcloudsdk.delete_volume(options)
          wait_resource(disk_id, "noexist", method(:get_disk_status))
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
        disk = has_disk?(ret_info)
        cloud_error("Volume `#{disk_id}' not found") unless disk

        device_name = attach_volume(ret_info, instance_id)

        update_agent_settings(instance_id) do |settings|
          settings["disks"] ||= {}
          settings["disks"]["persistent"] ||= {}
          settings["disks"]["persistent"][disk_id] = device_name
        end
        logger.info("Attached `#{disk_id}' to `#{instance_id}'")
      end
    end

    ##
    # Attaches an HwCloud volume to an OpenStack server
    #
    # @param disk id
    # @param instance id
    # @return [String] Device name
    def attach_volume(disk_info, instance_id)
      puts disk_info
      disk_status = disk_info["volumeSet"]["volumeSet"][0]["status"]
      disk_id = disk_info["volumeSet"]["volumeSet"][0]["volumeId"]
      if disk_status != "available"
        instance_disk_id = disk_info["volumeSet"]["volumeSet"][0]["attachmentSet"]["attachmentSet"][0]["instanceId"]
        cloud_error("Instance `#{instance_id}' is not attach to #{disk_id}") unless instance_disk_id == instance_id
      end

      if disk_status == "available"
        options={
          :VolumeId   => "#{disk_id}",
          :InstanceId => "#{instance_id}"
        }
        attachment = @hwcloudsdk.attach_volume(options)
        wait_resource(disk_id, "in-use", method(:get_disk_status))
      else
        @logger.info("Disk `#{disk_id}' is already attached to server `#{instance_id}'. Skipping.")
      end

      ret_info = get_disks(disk_id)
      ret_info["volumeSet"]["volumeSet"][0]["attachmentSet"]["attachmentSet"] [0]["device"]
    end

    # Detach an EBS volume from an EC2 instance
    # @param [String] instance_id EC2 instance id of the virtual machine to detach the disk from
    # @param [String] disk_id EBS volume id of the disk to detach
    def detach_disk(instance_id, disk_id)
      with_thread_name("detach_disk(#{instance_id}, #{disk_id})") do
        instance = has_vm?(instance_id)
        cloud_error("Instance `#{instance_id}' not found") unless instance

        ret_info = get_disks(disk_id)
        disk = has_disk?(ret_info)
        cloud_error("Volume `#{disk_id}' not found") unless disk

        disk_instance_id = ret_info["volumeSet"]["volumeSet"][0]["attachmentSet"]["attachmentSet"][0]["instanceId"]
        if disk_instance_id == instance_id

          options={:VolumeId   => "#{disk_id}",
                   :InstanceId => "#{instance_id}"}
          stop_vm(instance_id)
          detachment = @hwcloudsdk.detach_volume(options)
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

    def stop_vm(instance_id)
      with_thread_name("has_vm?(#{instance_id})") do
        options = {'InstanceId[0]'.to_sym => instance_id}
        instance = @hwcloudsdk.stop_instances(options)
        wait_resource(instance_id, "stopped", method(:get_vm_status))
      end
    end

#by zxy
    def get_disks(disk_id)
      with_thread_name("get_disks(#{disk_id})") do
      
      options={
    :'VolumeId[0]'          => "#{disk_id}",
    #:AvailabilityZone  =>  'b451c1ea3c8d4af89d03e5cacf1e4276'
      }
        ret = @hwcloudsdk.describe_volumes(options)
      end
    end


    def analyse_disk_state(disk_info) 
      if disk_info["volumeSet"] == nil || disk_info["volumeSet"]["volumeSet"].empty?
         state = "noexist" 
      else 
         state = disk_info["volumeSet"]["volumeSet"][0]["status"] 
      end
    end	

    def get_disk_status(disk_id)
      with_thread_name("get_disk_status(#{disk_id})") do
        ret_info = get_disks(disk_id)
        puts ret_info
        return analyse_disk_state(ret_info)
      end
    end

    def has_disk?(disk_info)
      state = analyse_disk_state(disk_info)
      return false if state == 'noexist'
      true
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

        options={
         :'InstanceId[0]' => instance_id,
        }

        instance_info = @hwcloudsdk.describe_instances(options)

        if instance_info[instancesSet] == nil 
          cloud_error("Can not find the Instance")
        end

        network_configurator = NetworkConfigurator.new(network_spec)

        # compare_security_groups(instance, network_spec)

        # compare_private_ip_addresses(instance, network_configurator.private_ip)

        # network_configurator.configure(@ec2, instance)

        network_configurator.configure(@hwcloudsdk, instance_info)

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

        options={
          :'Filter[0].Name' => 'imageName',
          :'Filter[0].Value[0]' => "hwcloud_stemcell",
        }

        stemcell_info = @hwcloudsdk.describe_images_by_name(options)

        if stemcell_info["imageSet"]["imageSet"].empty?
          raise "can't find the stemcell"
        end

        image_id = stemcell_info["imageSet"]["imageSet"][0]["imageId"]
      end
    end

    # Delete a stemcell and the accompanying snapshots
    # @param [String] stemcell_id  name of the stemcell to be deleted
    def delete_stemcell(stemcell_id)
      with_thread_name("delete_stemcell(#{stemcell_id})") do
        options={
          :'Filter[0].Name' => 'imageID',
          :'Filter[0].Value[0]' => "#{stemcell_id}",
        }
        image = @hwcloudsdk.describe_images_by_name(options)


        if image["imageSet"]["imageSet"].empty?

          @logger.info("Stemcell `#{stemcell_id}' not found. Skipping.")

        elsif image["imageSet"]["imageSet"][0]["imageFolderName"] == nil
          @logger.info("Stemcell `#{stemcell_id}' is base stemell.Can not delee. Skipping.")
         else
           options={
             :'ImageFolderName[0]' => "#{image["imageSet"]["imageSet"][0]["imageFolderName"]}",
           }
           ret = @hwcloudsdk.delete_images(options)
           @logger.info("Stemcell `#{stemcell_id}' is now deleted")
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

    def hwcloud_properties
      @hwcloud_properties ||= options.fetch('hwcloud')
    end

    def qingcloud_region
      @qingcloud_region ||= qingcloud_properties.fetch('region', nil)
    end

    def fast_path_delete?
      qingcloud_properties.fetch('fast_path_delete', false)
    end


    def initialize_hwcloud
      hwcloud_logger = logger
      hwcloud_params = {
          :url =>            hwcloud_properties['url'],
          :HWSAccessKeyId =>            hwcloud_properties['access_key_id'],
          :Version=>     hwcloud_properties['version'],
          :SignatureMethod=> hwcloud_properties['signature_method'],
          :SignatureNonce=> hwcloud_properties['signature_nonce'],
          :SignatureVersion=> hwcloud_properties['signature_version'],
          :RegionName=> hwcloud_properties['region_name'],
          :Key=> hwcloud_properties['key'],
      }


      @wait_resource_poll_interval = hwcloud_properties["wait_resource_poll_interval"] || 5

      @availabilityzone=hwcloud_properties["availability_zone"]
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

      option = {:'InstanceId[0]' => "#{instance_id}"}
      instance_info = @hwcloudsdk.describe_instances(option)
      puts instance_info["instancesSet"]
      if instance_info["instancesSet"]
        # settings = registry.read_settings(instance_id)
        puts instance_info["instancesSet"]["instancesSet"][0]["instanceName"]
        settings = registry.read_settings(instance_info["instancesSet"]["instancesSet"][0]["instanceName"])
        yield settings
        registry.update_settings(instance_info["instancesSet"]["instancesSet"][0]["instanceName"], settings)
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
          "hwcloud" => ["url", "HWSAccessKeyId", "Version", "SignatureMethod","SignatureNonce", "SignatureVersion", "RegionName", "Key","AvailabilityZone"],
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

