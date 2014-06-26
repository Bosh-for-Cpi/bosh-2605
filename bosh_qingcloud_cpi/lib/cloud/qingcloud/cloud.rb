# Copyright (c) 2009-2012 VMware, Inc.
require 'cloud/qingcloud/stemcell_finder'
require 'rubypython'
module Bosh::QingCloud

  class Cloud < Bosh::Cloud
    include Helpers

    # default maximum number of times to retry an AWS API call
    DEFAULT_MAX_RETRIES = 2
    METADATA_TIMEOUT    = 5 # in seconds
    DEVICE_POLL_TIMEOUT = 60 # in seconds

    attr_reader   :ec2
    attr_reader   :registry
    attr_reader   :options
    attr_accessor :logger

    ##
    # Initialize BOSH QingCloud CPI. The contents of sub-hashes are defined in the {file:README.md}
    # @param [Hash] options CPI options
    # @option options [Hash] aws AWS specific options
    # @option options [Hash] agent agent options
    # @option options [Hash] registry agent options
    def initialize(options)
      @options = options.dup.freeze
      validate_options

      @logger = Bosh::Clouds::Config.logger

      initialize_qingcloud
      initialize_registry

      @metadata_lock = Mutex.new
      print "initialize Finish!!\r\n"
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

        #get security groups
        qingcloud_security_groups = @qingcloudsdk.describe_security_groups()
        security_groups = network_configurator.security_groups(@default_security_groups)
        print "security_groups = #{security_groups}\r\n"
        #check security_group

        @logger.debug("Using security groups: `#{security_groups.join(', ')}'")
        
        nics = network_configurator.nics
        @logger.debug("Using NICs: `#{nics.join(', ')}'")
        
        #check image 
        image = @qingcloudsdk.describe_images(stemcell_id)

        cloud_error("Image `#{stemcell_id}' not found") if image["total_count"] == 0
        @logger.debug("Using image: `#{stemcell_id}'")

        #check instance type

        @logger.debug("Using flavor: `#{resource_pool['instance_type']}'")
        
        #check keypair
        keyname = resource_pool['key_name'] || @default_key_name
        keypair = @qingcloudsdk.describe_key_pairs(keyname)

        cloud_error("Key-pair `#{keyname}' not found") if keypair["total_count"] != 1
        @logger.debug("Using key-pair: `#{keypair["keypair_set"][0]["keypair_name"]}'")

        instance_info = @qingcloudsdk.run_instances(stemcell_id, server_name, 
          resource_pool['instance_type'], "vxnet-0", security_groups[0], 'keypair', keypair["keypair_set"][0]["keypair_id"])
	
        cloud_error("run_instances is failed, #{instance_info["message"]}") if instance_info["ret_code"] != 0
        @logger.info("Creating new server `#{server_name}'...")

        begin
          wait_resource(instance_info["instances"][0], "running", method(:get_vm_status))
        rescue Bosh::Clouds::CloudError => e
          @logger.warn("Failed to create server: #{e.message}")
          @qingcloudsdk.terminate_instances(instance_info["instances"][0])
          raise Bosh::Clouds::VMCreationFailed.new(true)
        end

        #associate floationg ip
        @logger.info("Configuring network for server `#{instance_info["instances"][0]}'...")
        network_configurator.configure(@qingcloudsdk, instance_info)

      end
        
    end

    def default_ec2_endpoint
      ['ec2', aws_region, 'amazonaws.com'].compact.join('.')
    end

    def default_elb_endpoint
      ['elasticloadbalancing', aws_region, 'amazonaws.com'].compact.join('.')
    end

    ##
    # Delete Qing instance ("terminate" in Qing language) and wait until
    # it reports as terminated
    # @param [String] instance_id EC2 instance id
    def delete_vm(instance_id)
      with_thread_name("delete_vm(#{instance_id})") do
        logger.info("Deleting instance '#{instance_id}'")
        ret = @qingcloudsdk.terminate_instances(instance_id)
      end
    end

    ##
    # Reboot Qing instance
    # @param [String] instance_id Qing instance id
    def reboot_vm(instance_id)
      with_thread_name("reboot_vm(#{instance_id})") do
        ret = @qingcloudsdk.restart_instances(instance_id)
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
    def create_disk(size, volume_name = nil)
      with_thread_name("create_disk(#{size}, #{volume_name})") do
        validate_disk_size(size)

        # if the disk is created for an instance, use the same availability zone as they must match
        volume = @qingcloudsdk.create_volumes(size / 1024 , volume_name, 1)
        volume_info = RubyPython::Conversion.ptorDict(volume.pObject.pointer)

        logger.info("Creating volume '#{volume["volumes"]}'")
        wait_resource(volume_info["volumes"][0], "available", method(:get_disk_status))
        volume_info["volumes"][0]
      end
    end

    def validate_disk_size(size)
      raise ArgumentError, "disk size needs to be an integer" unless size.kind_of?(Integer)
      raise ArgumentError, "disk size needs to be Divisible by 10" unless (size % 10 == 0)

      cloud_error("QingCloud CPI minimum disk size is 10  GiB") if size < 1024 * 10
      cloud_error("QingCloud CPI maximum disk size is 500 GiB") if size > 1024 * 500
    end

    ##
    # Delete qingcloud volume
    # @param [String] disk_id qingcloud volume id
    # @raise [Bosh::Clouds::CloudError] if disk is not in available state
    def delete_disk(disk_id)
      with_thread_name("delete_disk(#{disk_id})") do
        @logger.info("Deleting volume `#{disk_id}'...")
        volume_info = @qingcloudsdk.describe_volumes(disk_id)
        if volume_info["total_count"] == 1

          state = volume_info["volume_set"][0]["status"]
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
        unless instance["total_count"] == 1
          raise "does not exist the instance"
        end  
        
        ret_info = get_disks(disk_id)
        unless ret_info["total_count"] == 1
          raise "does not exist the disk"
        end 
        device_name=  ret_info["volume_set"][0]["volume_name"] 
        deivice_instance_id = ret_info["volume_set"][0]["instance"]["instance_id"]

        if deivice_instance_id.nil? || deivice_instance_id.empty?
          attachment = @qingcloudsdk.attach_volumes([disk_id],instance_id)

          # wait_resource(disk_id, "in-use", method(:get_disk_status))

          update_agent_settings(instance_id) do |settings|
            settings["disks"] ||= {}
            settings["disks"]["persistent"] ||= {}
            settings["disks"]["persistent"][disk_id] = device_name
          end
        end
        logger.info("Attached `#{disk_id}' to `#{instance_id}'")

        device_name
      end
    end

    # Detach an EBS volume from an EC2 instance
    # @param [String] instance_id EC2 instance id of the virtual machine to detach the disk from
    # @param [String] disk_id EBS volume id of the disk to detach
    def detach_disk(instance_id, disk_id)
      with_thread_name("detach_disk(#{instance_id}, #{disk_id})") do
        instance = has_vm?(instance_id)
        unless instance["total_count"] == 1
          raise "does not exist the instance"
        end 
        ret_info = get_disks(disk_id)
        unless ret_info["total_count"] == 1
          raise "does not exist the disk"
        end 
        deivice_instance_id = ret_info["volume_set"][0]["instance"]["instance_id"]
        if deivice_instance_id.nil? || deivice_instance_id.empty?
          raise "instance does not exist the disk"
        end

        detachment = @qingcloudsdk.detach_volumes([disk_id],instance_id)

        update_agent_settings(instance_id) do |settings|
         settings["disks"] ||= {}
         settings["disks"]["persistent"] ||= {}
         settings["disks"]["persistent"].delete(disk_id)
        end

        #detach_ebs_volume(instance, volume)

        logger.info("Detached `#{disk_id}' from `#{instance_id}'")
        print detachment
      end
    end

    def get_disks(vm_id)
      with_thread_name("get_disks(#{vm_id})") do
        ret = @qingcloudsdk.describe_volumes(vm_id)
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
    def snapshot_disk(resources, snapshot_name)
      with_thread_name("snapshot_disk(#{resources})") do

        ret = @qingcloudsdk.create_snapshots(resources, snapshot_name)
        
        wait_resource(ret["snapshots"][0], "available", method(:get_snapshot_status))
        
        logger.info("snapshot '#{snapshot_name}' of volume '#{resources}' created")
        ret["snapshots"][0]
      end
    end

    # Delete a disk snapshot
    # @param [String] snapshot_id snapshot id to delete
    def delete_snapshot(snapshot_id)
      with_thread_name("delete_snapshot(#{snapshot_id})") do
        snapshot_info = @qingcloudsdk.describe_snapshot(snapshot_id)
        
        if snapshot_info["total_count"] == 1
          status = snapshot_info["snapshot_set"][0]["status"]
          

          if status == "available"
            ret = @qingcloudsdk.delete_snapshots(snapshot_id)
            snapshot_after_delete = @qingcloudsdk.describe_snapshot(snapshot_id)
  
            wait_resource(snapshot_after_delete["snapshot_set"][0], "ceased", method(:get_snapshot_status))

          else
          logger.info("snapshot `#{snapshot_id}' not found. Skipping.")
          end 
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

        instance = @ec2.instances[instance_id]

        network_configurator = NetworkConfigurator.new(network_spec)

        compare_security_groups(instance, network_spec)

        compare_private_ip_addresses(instance, network_configurator.private_ip)

        network_configurator.configure(@ec2, instance)

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
        image = @qingcloudsdk.describe_images(stemcell_id)
        if image[:total_count] != 0
          ret = @qingcloudsdk.delete_images(stemcell_id)
          @logger.info("Stemcell `#{stemcell_id}' is now deleted")
        else
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
      @qingcloud_properties ||= options.fetch('qingcloud')
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
      #aws_params[:proxy_uri] = aws_properties['proxy_uri'] if aws_properties['proxy_uri']

      # AWS Ruby SDK is threadsafe but Ruby autoload isn't,
      # so we need to trigger eager autoload while constructing CPI
      #AWS.eager_autoload!

      #AWS.config(aws_params)

      #@ec2 = AWS::EC2.new
      #@region = @ec2.regions[aws_region]
      #@az_selector = AvailabilityZoneSelector.new(@region, aws_properties['default_availability_zone'])
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

      settings = registry.read_settings(instance_id)
      yield settings
      registry.update_settings(instance_id, settings)
    end

    def attach_ebs_volume(instance, volume)
      device_name = select_device_name(instance)
      cloud_error('Instance has too many disks attached') unless device_name

      # Work around AWS eventual (in)consistency:
      # even tough we don't call attach_disk until the disk is ready,
      # AWS might still lie and say that the disk isn't ready yet, so
      # we try again just to be really sure it is telling the truth
      attachment = nil
      Bosh::Common.retryable(tries: 15, on: AWS::EC2::Errors::IncorrectState) do
        attachment = volume.attach_to(instance, device_name)
      end

      logger.info("Attaching '#{volume.id}' to '#{instance.id}' as '#{device_name}'")
      ResourceWait.for_attachment(attachment: attachment, state: :attached)

      device_name = attachment.device
      logger.info("Attached '#{volume.id}' to '#{instance.id}' as '#{device_name}'")

      device_name
    end

    def select_device_name(instance)
      device_names = Set.new(instance.block_device_mappings.to_hash.keys)

      ('f'..'p').each do |char| # f..p is what console suggests
                                # Some kernels will remap sdX to xvdX, so agent needs
                                # to lookup both (sd, then xvd)
        device_name = "/dev/sd#{char}"
        return device_name unless device_names.include?(device_name)
        logger.warn("'#{device_name}' on '#{instance.id}' is taken")
      end

      nil
    end

    def detach_ebs_volume(instance, volume, force=false)
      mappings = instance.block_device_mappings.to_hash

      device_map = mappings.inject({}) do |hash, (device_name, attachment)|
        hash[attachment.volume.id] = device_name
        hash
      end

      if device_map[volume.id].nil?
        raise Bosh::Clouds::DiskNotAttached.new(true),
              "Disk `#{volume.id}' is not attached to instance `#{instance.id}'"
      end

      attachment = volume.detach_from(instance, device_map[volume.id], force: force)
      logger.info("Detaching `#{volume.id}' from `#{instance.id}'")

      ResourceWait.for_attachment(attachment: attachment, state: :detached)
    end

    ##
    # Checks if options passed to CPI are valid and can actually
    # be used to create all required data structures etc.
    #
    def validate_options
      required_keys = {
          "qingcloud" => ["region", "access_key_id", "secret_access_key"],
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

    # Generates initial agent settings. These settings will be read by agent
    # from AWS registry (also a BOSH component) on a target instance. Disk
    # conventions for amazon are:
    # system disk: /dev/sda
    # ephemeral disk: /dev/sdb
    # EBS volumes can be configured to map to other device names later (sdf
    # through sdp, also some kernels will remap sd* to xvd*).
    #
    # @param [String] agent_id Agent id (will be picked up by agent to
    #   assume its identity
    # @param [Hash] network_spec Agent network spec
    # @param [Hash] environment
    # @param [String] root_device_name root device, e.g. /dev/sda1
    # @return [Hash]
    def initial_agent_settings(agent_id, network_spec, environment, root_device_name)
      settings = {
          "vm" => {
              "name" => "vm-#{SecureRandom.uuid}"
          },
          "agent_id" => agent_id,
          "networks" => network_spec,
          "disks" => {
              "system" => root_device_name,
              "ephemeral" => "/dev/sdb",
              "persistent" => {}
          }
      }

      settings["env"] = environment if environment
      settings.merge(agent_properties)
    end
  end
end

