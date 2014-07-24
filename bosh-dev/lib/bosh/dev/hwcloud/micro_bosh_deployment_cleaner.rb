require 'logger'
require 'sequel'
require 'sequel/adapters/sqlite'
require 'cloud/hwcloud'
require 'common/retryable'
require 'bosh/dev/hwcloud'

module Bosh::Dev::Hwcloud
  class MicroBoshDeploymentCleaner
    def initialize(manifest)
      @manifest = manifest
      @logger = Logger.new($stderr)
    end

    def clean
      configure_cpi

      cloud = Bosh::HwCloud::Cloud.new(@manifest.cpi_options)

      servers_collection = cloud.hwcloud.servers

      Bosh::Retryable.new(tries: 20, sleep: 20).retryer do
        # HwCloud does not return deleted servers on subsequent calls
        servers = find_any_matching_servers(servers_collection)

        matching_server_names = servers.map(&:name).join(', ')
        @logger.info("Destroying servers #{matching_server_names}")

        # calling destroy on a server multiple times is ok
        servers.each { |s| clean_server(s) }

        servers.empty?
      end

      # destroy all images
      cloud.hwcloud.images.all.each do |image|
        if image.name =~ /^BOSH/
          @logger.info("Destroying image #{image.name}")
          # image.destroy
        else
          @logger.info("Ignoring image #{image.name}")
        end
      end

      # destroy unattached volumes
      cloud.hwcloud.volumes.all.each do |volume|
        if volume.attachments == [{}]
          @logger.info("Destroying volume #{volume.name}")
          # volume.destroy
        end
      end
    end

    def clean_server(server)
      server.volumes.each do |volume|
        volume.attachments.each do |atth|
          volume.detach(atth['serverId'], atth['id'])
        end

        # HwCloud does not allow to delete a volume
        # until its status becomes 'available'.
        # Status turns from 'in-use' to 'available'
        # some time after deleting all attachments.
        options = { tries: 10, sleep: 5, on: [Excon::Errors::BadRequest] }
        Bosh::Retryable.new(options).retryer { volume.destroy }
      end

      server.destroy
    end

    private

    def configure_cpi
      Bosh::Clouds::Config.configure(OpenStruct.new(
        logger: @logger,
        uuid: nil,
        task_checkpoint: nil,
        db: Sequel.sqlite,
      ))
    end

    def find_any_matching_servers(servers_collection)
      # Assumption here is that when director deploys instances
      # it properly tags them with director's name.
      servers_collection.all.select do |server|
        tags = server.metadata.to_hash.values_at('Name', 'director')
        tags.include?(@manifest.director_name)
      end
    end
  end
end
