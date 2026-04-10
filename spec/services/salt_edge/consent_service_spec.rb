# frozen_string_literal: true

RSpec.describe SaltEdge::ConsentService do
  let(:config) do
    instance_double(
      SaltEdge::Config,
      redirect_uri: 'https://example.ngrok.io/callback',
      psu_ip_address: '9.9.9.9'
    )
  end
  let(:request_adapter) { instance_double(SaltEdge::RequestAdapter) }

  subject(:service) { described_class.new(config: config, request_adapter: request_adapter) }

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

    it 'calls adapter with expected endpoint, headers, and payload' do
      allow(request_adapter).to receive(:request).and_return(
        SaltEdge::RequestResult.new(status: 201, data: upstream_data)
      )

      result = service.create_consent(state: 'abc state', valid_until: Date.new(2026, 12, 31))

      expect(request_adapter).to have_received(:request).with(
        method: :post,
        path: '/v1/consents',
        headers: hash_including(
          'Content-Type' => 'application/json',
          'TPP-Redirect-Preferred' => 'true',
          'TPP-Redirect-URI' => 'https://example.ngrok.io/callback?state=abc+state',
          'PSU-IP-Address' => '9.9.9.9'
        ),
        body: hash_including(
          access: { allPsd2: 'allAccounts' },
          recurringIndicator: true,
          validUntil: '2026-12-31',
          frequencyPerDay: 4,
          combinedServiceIndicator: false
        )
      )

      expect(result).to eq(
        'consent_id' => 'consent-123',
        'consent_status' => 'received',
        'sca_redirect_url' => 'https://aspsp.example/sca',
        'raw' => upstream_data
      )
    end


    it 'raises when adapter returns failure result' do
      error = SaltEdge::RequestError.new('upstream failed', status: 400)
      allow(request_adapter).to receive(:request).and_return(
        SaltEdge::RequestResult.new(status: 400, error: error)
      )

      expect { service.create_consent(state: 'abc') }.to raise_error(SaltEdge::RequestError, 'upstream failed')
    end
  end

  describe '#consent_status' do
    it 'calls status endpoint and returns consentStatus' do
      allow(request_adapter).to receive(:request).and_return(
        SaltEdge::RequestResult.new(status: 200, data: { 'consentStatus' => 'valid' })
      )

      result = service.consent_status('consent-123')

      expect(request_adapter).to have_received(:request).with(
        method: :get,
        path: '/v1/consents/consent-123/status'
      )
      expect(result).to eq('valid')
    end
  end
end
