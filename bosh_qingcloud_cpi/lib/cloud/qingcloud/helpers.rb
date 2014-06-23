# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::QingCloud

  module Helpers

    ##
    # Raises CloudError exception
    #
    def cloud_error(message)
      if @logger
        @logger.error(message)
      end
      raise Bosh::Clouds::CloudError, message
    end

    def extract_security_group_names(networks_spec)
      networks_spec.
          values.
          select { |network_spec| network_spec.has_key? "cloud_properties" }.
          map { |network_spec| network_spec["cloud_properties"] }.
          select { |cloud_properties| cloud_properties.has_key? "security_groups" }.
          map { |cloud_properties| Array(cloud_properties["security_groups"]) }.
          flatten.
          sort.
          uniq
    end

    DEFAULT_STATE_TIMEOUT = 300 # Default timeout for target state (in seconds)
    MAX_RETRIES = 10 # Max number of retries
    DEFAULT_RETRY_TIMEOUT = 3 # Default timeout before retrying a call (in seconds)

    def with_QingCloud
      retries = 0
      begin
        yield
      rescue "aaaaa"#Excon::Errors::RequestEntityTooLarge => e
        # If we find a rate limit error, parse message, wait, and retry
        overlimit = parse_qingcloud_response(e.response, "overLimit", "overLimitFault")
        unless overlimit.nil? || retries >= MAX_RETRIES
          task_checkpoint
          wait_time = overlimit["retryAfter"] || e.response.headers["Retry-After"] || DEFAULT_RETRY_TIMEOUT
          details = "#{overlimit["message"]} - #{overlimit["details"]}"
          @logger.debug("OpenStack API Over Limit (#{details}), waiting #{wait_time} seconds before retrying") if @logger
          sleep(wait_time.to_i)
          retries += 1
          retry
        end
        cloud_error("OpenStack API Request Entity Too Large error. Check task debug log for details.", e)
      rescue "=================="#Excon::Errors::BadRequest => e
        badrequest = parse_qingcloud_response(e.response, "badRequest")
        details = badrequest.nil? ? "" : " (#{badrequest["message"]})"   
        cloud_error("OpenStack API Bad Request#{details}. Check task debug log for details.", e)
      rescue "++++++++++++++"#Excon::Errors::InternalServerError => e
        unless retries >= MAX_RETRIES
          retries += 1
          @logger.debug("OpenStack API Internal Server error, retrying (#{retries})") if @logger
          sleep(DEFAULT_RETRY_TIMEOUT)
          retry
        end
        cloud_error("OpenStack API Internal Server error. Check task debug log for details.", e)
      end
    end
    
    ##
    # Parses and look ups for keys in an OpenStack response 
    #
    # @param [Excon::Response] response Response from OpenStack API
    # @param [Array<String>] keys Keys to look up in response
    # @return [Hash] Contents at the first key found, or nil if not found
    def parse_qingcloud_response(response, *keys)
      unless response.body.empty?
        begin
          body = JSON.parse(response.body)
          key = keys.detect { |k| body.has_key?(k)}
          return body[key] if key
        rescue JSON::ParserError
          # do nothing
        end
      end
      nil
    end

    ##
    # Waits for a resource to be on a target state
    #
    # @param [Fog::Model] resource Resource to query
    # @param [Array<Symbol>] target_state Resource's state desired
    # @param [Symbol] state_method Resource's method to fetch state
    # @param [Boolean] allow_notfound true if resource could be not found
    def wait_resource(id, target_state, callback, allow_notfound = false)

      started_at = Time.now
      # desc = resource.class.name.split("::").last.to_s + " `" + resource.id.to_s + "'"
      desc = id
      target_state = Array(target_state)
      state_timeout = @state_timeout || DEFAULT_STATE_TIMEOUT

      loop do
        task_checkpoint

        duration = Time.now - started_at

        if duration > state_timeout
          cloud_error("Timed out waiting for #{desc} to be #{target_state.join(", ")}")
        end

        if @logger
          @logger.debug("Waiting for #{desc} to be #{target_state.join(", ")} (#{duration}s)")
        end

        state = callback.call(id)
        # This is not a very strong convention, but some resources
        # have 'error', 'failed' and 'killed' states, we probably don't want to keep
        # waiting if we're in these states. Alternatively we could introduce a
        # set of 'loop breaker' states but that doesn't seem very helpful
        # at the moment
        if state == :error || state == :failed || state == :killed
          cloud_error("#{desc} state is #{state}, expected #{target_state.join(", ")}")
        end

        break if target_state.include?(state)

        sleep(@wait_resource_poll_interval)
        
      end

      if @logger
        total = Time.now - started_at
        @logger.info("#{desc} is now #{target_state.join(", ")}, took #{total}s")
      end
    end

    def task_checkpoint
      Bosh::Clouds::Config.task_checkpoint
    end

  end
end

