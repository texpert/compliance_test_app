# frozen_string_literal: true

# Thin wrapper around HTTPX that centralizes request/response logging.
class HttpxClient
  @session_mutex = Mutex.new

  class << self
    def session
      return @session if @session

      @session_mutex.synchronize do
        @session ||= build_new_session
      end
    end

    private

    def build_new_session
      HTTPX.plugin(:callbacks)
           .on_request_started { |request| handle_request_started(request) }
           .on_response_completed { |request, response| handle_response_completed(request, response) }
           .on_request_error { |request, error| handle_request_error(request, error) }
    end

    def handle_request_started(request)
      return if request.instance_variable_get(:@_logged_started)

      request.instance_variable_set(:@_logged_started, true)
      request.instance_variable_set(:@log_start_time, Process.clock_gettime(Process::CLOCK_MONOTONIC))

      log_prefix = "service=HTTPX, caller=#{determine_caller_name}, method=#{request.verb}, uri=#{request.uri}"
      trace_ids = { uid: SecureRandom.uuid }

      request.instance_variable_set(:@log_prefix, log_prefix)
      request.instance_variable_set(:@log_trace_ids, trace_ids)

      Rails.logger.info(
        "Request started: #{Time.current.utc.iso8601(3)}, #{log_prefix}, #{trace_ids}, " \
        "Headers: #{safe_headers(request)}, Body: #{safe_body(request)}"
      )
    end

    def handle_response_completed(request, response)
      return if request.instance_variable_get(:@_logged_completed)

      request.instance_variable_set(:@_logged_completed, true)

      log_prefix = request.instance_variable_get(:@log_prefix)
      trace_ids = request.instance_variable_get(:@log_trace_ids) || {}
      duration = elapsed_duration(request)

      if response.status.between?(200, 299)
        Rails.logger.info(
          "Response completed: #{Time.current.utc.iso8601(3)}, #{log_prefix}, #{trace_ids}, " \
          "status=#{response.status}, Headers: #{safe_headers(response)}, Body: #{safe_body(response)}, Duration: #{duration}s"
        )
      else
        Rails.logger.error(
          "HTTPX request failed: #{log_prefix}, #{trace_ids}, time=#{Time.current.utc.iso8601(3)}, " \
          "status=#{response.status}, response_headers=#{safe_headers(response)}, " \
          "response_body=#{safe_body(response)}, duration=#{duration}s"
        )
      end
    end

    def handle_request_error(request, error)
      return if request.instance_variable_get(:@_logged_error)

      request.instance_variable_set(:@_logged_error, true)

      log_prefix = request.instance_variable_get(:@log_prefix)
      trace_ids = request.instance_variable_get(:@log_trace_ids) || {}
      duration = elapsed_duration(request)

      Rails.logger.error(
        "HTTPX request error: #{log_prefix}, #{trace_ids}, time=#{Time.current.utc.iso8601(3)}, " \
        "error_class=#{error.class.name}, error_message=#{error.message}, duration=#{duration}s"
      )
    end

    def elapsed_duration(request)
      start_time = request.instance_variable_get(:@log_start_time)
      return 0.0 unless start_time

      (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time).round(4)
    end

    def safe_headers(object)
      return {} unless object.respond_to?(:headers)

      headers = object.headers
      headers.respond_to?(:to_h) ? headers.to_h : headers
    end

    def safe_body(object)
      return nil unless object.respond_to?(:body)

      object.body
    end

    def determine_caller_name
      caller_location = caller_locations.find do |loc|
        path = loc.path
        path.exclude?('httpx') && path.exclude?('http-2') && path.exclude?('<internal')
      end

      caller_location ? File.basename(caller_location.path, '.rb').camelize : 'Unknown'
    end
  end
end
