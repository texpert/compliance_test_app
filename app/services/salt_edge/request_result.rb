# frozen_string_literal: true

module SaltEdge
  class RequestResult
    attr_reader :status, :data, :error

    def initialize(status:, data: {}, error: nil)
      @status = status
      @data = data
      @error = error
    end

    def success?
      @error.nil?
    end

    def failure?
      !success?
    end
  end
end
