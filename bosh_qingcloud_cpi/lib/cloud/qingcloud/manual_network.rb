module Bosh::QingCloud
  ##
  #
  class ManualNetwork < Network

    attr_reader :subnet

    # create manual network
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
    end

    def private_ip
      @ip
    end

    def configure(qingcloud, instance)

    end
  end
end