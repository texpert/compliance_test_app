# frozen_string_literal: true

require 'cgi'

module SaltEdge
  class ConsentService
    def initialize(config: SaltEdge::Config.new, request_adapter: nil, certificate: nil)
      @config = config
      @request_adapter = request_adapter || build_adapter(certificate)
    end

    def create_consent(consent_id:, psu_ip_address: nil, valid_until: Date.current + 180)
      payload = consent_payload(valid_until)
      result = perform_consent_request(
        consent_id: consent_id,
        psu_ip_address: psu_ip_address,
        payload: payload
      )
      raise result.error if result.failure?

      map_response(result.data)
    end

    # Perform upstream consent creation, record an Event, and persist upstream identifiers.
    # Create the local Consent first (so its id is available for the redirect URI), then call this.
    def create_and_persist_consent(consent:, psu_ip_address: nil, valid_until: Date.current + 180)
      payload = consent_payload(valid_until)
      result = perform_consent_request(
        consent_id: consent.id,
        psu_ip_address: psu_ip_address,
        payload: payload
      )

      record_event(consent: consent, request_body: payload, result: result)
      raise result.error if result.failure?

      resp = map_response(result.data)

      consent.upstream_consent_id = resp['consent_id']
      consent.status = Consent.status_value(resp['consent_status'])
      consent.save!

      resp
    end

    def consent_status(consent_id)
      response = @request_adapter.request(
        method: :get,
        path: "/#{@config.api_provider_code}/api/berlingroup/v1/consents/#{consent_id}/status"
      )
      raise response.error if response.failure?

      response.data['consentStatus']
    end

    private

    def perform_consent_request(consent_id:, psu_ip_address:, payload:)
      tpp_redirect_uri = redirect_uri(consent_id)
      headers = {
        'Content-Type' => 'application/json',
        'TPP-Redirect-Preferred' => 'true',
        'TPP-Redirect-URI' => tpp_redirect_uri,
        'PSU-IP-Address' => psu_ip_address || @config.psu_ip_address
      }.compact

      @request_adapter.request(
        method: :post,
        path: "/#{@config.api_provider_code}/api/berlingroup/v1/consents",
        headers: headers,
        sign_headers: { 'TPP-Redirect-URI' => tpp_redirect_uri },
        body: payload
      )
    end

    def map_response(data)
      {
        'consent_id' => data['consentId'],
        'consent_status' => data['consentStatus'],
        'sca_redirect_url' => data.dig('_links', 'scaRedirect', 'href'),
        'raw' => data
      }
    end

    def record_event(consent:, request_body:, result:)
      response_body = result.success? ? result.data : { 'error' => result.error.message, 'status' => result.status }
      Event.record(
        event_type: 'consent_create',
        provider: consent.provider,
        consent: consent,
        request_headers: result.request_headers,
        request_body: request_body,
        response_headers: result.response_headers,
        response_body: response_body
      )
    end

    def build_adapter(certificate)
      signer = SaltEdge::SignatureBuilder.new(certificate: certificate)
      SaltEdge::RequestAdapter.new(signer: signer)
    end

    def consent_payload(valid_until)
      {
        access: { allPsd2: 'allAccounts' },
        recurringIndicator: true,
        validUntil: valid_until.to_date.iso8601,
        frequencyPerDay: 4,
        combinedServiceIndicator: false
      }
    end

    def redirect_uri(consent_id)
      base = (Rails.env.development? && defined?(NGROK_URL)) ? NGROK_URL : @config.callback_base_url
      uri_with_consent_id(base, consent_id)
    end

    def uri_with_consent_id(base_uri, consent_id)
      "#{base_uri.chomp('/')}/callback/#{CGI.escape(consent_id.to_s)}"
    end
  end
end
