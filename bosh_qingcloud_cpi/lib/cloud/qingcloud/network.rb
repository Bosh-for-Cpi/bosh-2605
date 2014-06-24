# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::QingCloud
  ##
  #
  class Network
    include Helpers

    ##
    # Creates a new network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      unless spec.is_a?(Hash)
        raise ArgumentError, "Invalid spec, Hash expected, " \
                             "#{spec.class} provided"
      end

      @logger = Bosh::Clouds::Config.logger

      @name = name
      @ip = spec["ip"]
      @cloud_properties = spec["cloud_properties"]
    end

    ##
    # Configures given instance
    def configure(qingcloud, instance)
      cloud_error("`configure' not implemented by #{self.class}")
    end

  end
end
