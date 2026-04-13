# frozen_string_literal: true

module AisCallbacks
  class CallbackProcessor
    DEFAULT_EVENT_TYPE = 'authorization_callback'

    EVENT_HANDLERS = {
      DEFAULT_EVENT_TYPE => AisCallbacks::Handlers::AuthorizationCallbackHandler
    }.freeze

    # Entry point. Accepts either an ActionDispatch request or explicit keyword arguments
    # (for backward compatibility and direct unit testing).
    def call(request: nil, consent: nil, event_type: nil, callback_state: nil, code: nil, callback_params: nil, callback_request_headers: nil)
      if request
        parsed = extract_from_request(request)
        event_type               ||= parsed[:event_type]
        callback_params          ||= parsed[:callback_params]
        code                     ||= parsed[:code]
        callback_state           ||= parsed[:callback_state]
        consent                  ||= parsed[:consent]
        callback_request_headers ||= parsed[:headers]
      end

      request_body = (callback_params || {}).merge('event_type' => event_type, 'code' => code)
      request_body['consent_id'] = consent.id if consent

      if consent.nil?
        return error_result(:bad_request,  { 'error' => 'missing_state' },       request_body: request_body) if callback_state.to_s.blank?
        return error_result(:not_found,    { 'error' => 'consent_not_found' },   request_body: request_body)
      end

      handler = handler_for(event_type)
      unless handler
        return error_result(
          :unprocessable_content,
          { 'error' => 'unsupported_event_type', 'event_type' => event_type },
          consent: consent, headers: callback_request_headers, request_body: request_body
        )
      end

      result = handler.call(
        consent: consent,
        callback_state: callback_state,
        code: code,
        callback_params: callback_params,
        callback_request_headers: callback_request_headers
      )

      record_callback_event(
        response_body: result.response_body || result.error_body || {},
        consent: consent, headers: callback_request_headers, request_body: request_body
      )

      result
    rescue SaltEdge::RequestError => e
      consent&.update(callback_error: e.message)
      error_result(
        :bad_gateway,
        { 'error' => 'upstream_error', 'message' => e.message },
        consent: consent, headers: callback_request_headers, request_body: request_body
      )
    end

    private

    def extract_from_request(request)
      qp = request.query_parameters
      {
        event_type:      request.params['event_type'].to_s.strip.presence || DEFAULT_EVENT_TYPE,
        callback_params: qp.slice('state', 'code'),
        code:            request.params['code'],
        callback_state:  qp['state'],
        consent:         Consent.find_by(id: request.params['id']),
        headers:         sanitize_headers(request)
      }
    end


    def sanitize_headers(request)
      request.headers.to_h.each_with_object({}) do |(key, value), memo|
        k = key.to_s
        next unless k.start_with?('HTTP_', 'CONTENT_')

        memo[k] = value.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      end
    end

    def record_callback_event(response_body:, request_body:, consent: nil, headers: nil)
      Event.record(
        event_type: 'callback',
        provider: consent&.provider,
        consent: consent,
        request_headers: headers || {},
        request_body: request_body,
        response_body: response_body
      )
    end

    # Record a callback event and return a HandlerResult.error in one step.
    # Used for every early-exit path in #call.
    def error_result(http_status, response_body, request_body:, consent: nil, headers: nil)
      record_callback_event(response_body: response_body, consent: consent, headers: headers, request_body: request_body)
      HandlerResult.error(http_status: http_status, error_body: response_body)
    end

    def handler_for(event_type)
      handler_class = EVENT_HANDLERS[event_type.to_s]
      return nil unless handler_class

      handler_class.new
    end
  end
end
