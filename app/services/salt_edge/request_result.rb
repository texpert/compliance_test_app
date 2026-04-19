# frozen_string_literal: true

module SaltEdge
  class RequestResult
    attr_reader :status, :data, :error, :request_headers, :response_headers

    def initialize(status:, data: {}, error: nil, request_headers: {}, response_headers: {})
      @status           = status
      @data             = data
      @error            = error
      @request_headers  = request_headers  || {}
      @response_headers = response_headers || {}
    end

    def success?
      @error.nil?
    end

    def failure?
      !success?
    end
  end
end
