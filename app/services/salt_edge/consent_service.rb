# frozen_string_literal: true

require 'cgi'

module SaltEdge
  class ConsentService
    def initialize(config: SaltEdge::Config.new, request_adapter: SaltEdge::RequestAdapter.new)
      @config = config
      @request_adapter = request_adapter
    end

    def create_consent(state:, psu_ip_address: nil, valid_until: Date.current + 90)
      headers = {
        'Content-Type' => 'application/json',
        'TPP-Redirect-Preferred' => 'true',
        'TPP-Redirect-URI' => redirect_uri(state),
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

    def consent_status(consent_id)
      response = @request_adapter.request(
        method: :get,
        path: "/v1/consents/#{consent_id}/status"
      )
      raise response.error if response.failure?

      response.data['consentStatus']
    end

    private

    def consent_payload(valid_until)
      {
        access: { allPsd2: 'allAccounts' },
        recurringIndicator: true,
        validUntil: valid_until.to_date.iso8601,
        frequencyPerDay: 4,
        combinedServiceIndicator: false
      }
    end

    def redirect_uri(state)
      uri_with_state(@config.redirect_uri, state)
    end


    def uri_with_state(base_uri, state)
      separator = base_uri.include?('?') ? '&' : '?'
      "#{base_uri}#{separator}state=#{CGI.escape(state)}"
    end
  end
end
