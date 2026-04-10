# frozen_string_literal: true

module SaltEdge
  class RequestError < StandardError
    attr_reader :status, :code, :upstream_body

    def initialize(message, status: nil, code: nil, upstream_body: nil)
      super(message)
      @status = status
      @code = code
      @upstream_body = upstream_body
    end
  end
end
