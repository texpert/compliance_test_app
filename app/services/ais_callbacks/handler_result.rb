# frozen_string_literal: true

module AisCallbacks
  class HandlerResult
    attr_reader :http_status, :error_body
    attr_reader :consent
    attr_reader :response_body

    def self.ok(consent: nil, response_body: nil)
      new(ok: true, consent: consent, response_body: response_body)
    end

    def self.error(http_status:, error_body:, response_body: error_body)
      new(ok: false, http_status: http_status, error_body: error_body, response_body: response_body)
    end

    def initialize(ok:, http_status: nil, error_body: nil, consent: nil, response_body: nil)
      @ok = ok
      @http_status = http_status
      @error_body = error_body
      @consent = consent
      @response_body = response_body
    end

    def ok?
      @ok
    end
  end
end
