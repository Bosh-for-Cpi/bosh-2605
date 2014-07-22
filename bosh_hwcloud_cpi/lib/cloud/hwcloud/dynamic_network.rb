# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::HwCloud
  ##
  #
  class DynamicNetwork < Network

    ##
    # Creates a new dynamic network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
    end

    def configure(hwcloud, instance)
    end
  end
end


