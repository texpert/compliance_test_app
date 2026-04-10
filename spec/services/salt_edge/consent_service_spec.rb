# frozen_string_literal: true

RSpec.describe SaltEdge::ConsentService do
  let(:consent_config) do
    instance_double(
      SaltEdge::Config,
      redirect_uri: 'https://example.ngrok.io/callback',
      psu_ip_address: '9.9.9.9'
    )
  end
  let(:adapter_config) { instance_double(SaltEdge::Config, api_base_url: 'https://priora.saltedge.com', http_timeout: 30) }
  let(:signer) { instance_double(SaltEdge::SignatureBuilder) }
  let(:request_adapter) { SaltEdge::RequestAdapter.new(config: adapter_config, signer: signer, client: HTTPX) }

  subject(:service) { described_class.new(config: consent_config, request_adapter: request_adapter) }

  describe '#create_consent' do
    let(:upstream_data) do
      {
        'consentId' => 'consent-123',
        'consentStatus' => 'received',
        '_links' => {
          'scaRedirect' => { 'href' => 'https://aspsp.example/sca' }
        }
      }
    end
    let(:signed_headers) do
      {
        'Signature' => 'sig',
        'Digest' => 'SHA-256=abc',
        'X-Request-ID' => 'request-1',
        'Date' => 'Fri, 10 Apr 2026 12:00:00 GMT',
        'TPP-Signature-Certificate' => 'cert'
      }
    end

    before do
      allow(signer).to receive(:build_headers).and_return(signed_headers)
    end

    it 'creates a consent through the HTTP adapter and maps the response' do
      stub_request(:post, 'https://priora.saltedge.com/v1/consents')
        .to_return(status: 201, body: upstream_data.to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.create_consent(state: 'abc state', valid_until: Date.new(2026, 12, 31))

      expect(a_request(:post, 'https://priora.saltedge.com/v1/consents')).to have_been_made
      expect(
        a_request(:post, 'https://priora.saltedge.com/v1/consents').with(
          headers: {
            'TPP-Redirect-Preferred' => 'true',
            'TPP-Redirect-URI' => 'https://example.ngrok.io/callback?state=abc+state',
            'PSU-IP-Address' => '9.9.9.9',
            'Signature' => 'sig'
          },
          body: '{"access":{"allPsd2":"allAccounts"},"recurringIndicator":true,"validUntil":"2026-12-31","frequencyPerDay":4,"combinedServiceIndicator":false}'
        )
      ).to have_been_made

      expect(result).to eq(
        'consent_id' => 'consent-123',
        'consent_status' => 'received',
        'sca_redirect_url' => 'https://aspsp.example/sca',
        'raw' => upstream_data
      )
      expect(signer).to have_received(:build_headers).with(
        method: 'post',
        path: '/v1/consents',
        body: '{"access":{"allPsd2":"allAccounts"},"recurringIndicator":true,"validUntil":"2026-12-31","frequencyPerDay":4,"combinedServiceIndicator":false}'
      )
    end

    it 'raises when upstream returns a non-2xx response' do
      stub_request(:post, 'https://priora.saltedge.com/v1/consents')
        .to_return(status: 400, body: '{"tppMessages":[{"text":"upstream failed"}]}')

      expect { service.create_consent(state: 'abc') }.to raise_error(SaltEdge::RequestError, 'upstream failed')
    end
  end

  describe '#consent_status' do
    let(:signed_headers) do
      {
        'Signature' => 'sig',
        'Digest' => 'SHA-256=abc',
        'X-Request-ID' => 'request-1',
        'Date' => 'Fri, 10 Apr 2026 12:00:00 GMT',
        'TPP-Signature-Certificate' => 'cert'
      }
    end

    before do
      allow(signer).to receive(:build_headers).and_return(signed_headers)
    end

    it 'calls the status endpoint and returns consentStatus' do
      stub_request(:get, 'https://priora.saltedge.com/v1/consents/consent-123/status')
        .to_return(status: 200, body: '{"consentStatus":"valid"}', headers: { 'Content-Type' => 'application/json' })

      result = service.consent_status('consent-123')

      expect(a_request(:get, 'https://priora.saltedge.com/v1/consents/consent-123/status')).to have_been_made.once
      expect(result).to eq('valid')
    end
  end
end
