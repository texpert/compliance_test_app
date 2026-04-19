# frozen_string_literal: true

require 'cgi'

module SaltEdge
  class ConsentService
    def initialize(config: SaltEdge::Config.new, request_adapter: nil, certificate: nil)
      @config = config
      @request_adapter = request_adapter || build_adapter(certificate)
    end

    def create_consent(consent_id:, psu_ip_address: nil, valid_until: Date.current + 90)
      headers = {
        'Content-Type' => 'application/json',
        'TPP-Redirect-Preferred' => 'true',
        'TPP-Redirect-URI' => redirect_uri(consent_id),
        'PSU-IP-Address' => psu_ip_address || @config.psu_ip_address
      }.compact

      response = @request_adapter.request(
        method: :post,
        path: '/v1/consents',
        headers: headers,
        body: consent_payload(valid_until)
      )
      raise response.error if response.failure?

      data = response.data

      {
        'consent_id' => data['consentId'],
        'consent_status' => data['consentStatus'],
        'sca_redirect_url' => data.dig('_links', 'scaRedirect', 'href'),
        'raw' => data
      }
    end

    # Perform upstream consent creation and persist upstream identifiers into the local Consent record.
    # Create the local Consent first, then call this method to complete the upstream flow.
    def create_and_persist_consent(consent:, psu_ip_address: nil, valid_until: Date.current + 90)
      resp = create_consent(consent_id: consent.id, psu_ip_address: psu_ip_address, valid_until: valid_until)

      consent.upstream_consent_id = resp['consent_id']
      consent.status = Consent.status_value(resp['consent_status'])
      consent.save!

      resp
    end

    def consent_status(consent_id)
      response = @request_adapter.request(
        method: :get,
        path: "/v1/consents/#{consent_id}/status"
      )
      raise response.error if response.failure?

      response.data['consentStatus']
    end

    private

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
      uri_with_consent_id(@config.redirect_uri, consent_id)
    end

    def uri_with_consent_id(base_uri, consent_id)
      separator = base_uri.include?('?') ? '&' : '?'
      "#{base_uri}#{separator}id=#{CGI.escape(consent_id.to_s)}"
    end
  end
end
