# frozen_string_literal: true

RSpec.describe SaltEdge::AccountsService do
  let(:adapter_config) { instance_double(SaltEdge::Config, api_base_url: 'https://priora.saltedge.com', http_timeout: 30) }
  let(:signer) { instance_double(SaltEdge::SignatureBuilder) }
  let(:request_adapter) { SaltEdge::RequestAdapter.new(config: adapter_config, signer: signer, client: HTTPX) }

  subject(:service) { described_class.new(request_adapter: request_adapter) }

  describe '#accounts' do
    let(:upstream_accounts) do
      [
        { 'resourceId' => 'acc-001', 'iban' => 'DE00123456789', 'currency' => 'EUR', 'name' => 'Checking' },
        { 'resourceId' => 'acc-002', 'iban' => 'DE00987654321', 'currency' => 'EUR', 'name' => 'Savings' }
      ]
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

    it 'requests GET /v1/accounts with Consent-ID header' do
      stub_request(:get, 'https://priora.saltedge.com/v1/accounts')
        .to_return(status: 200, body: { accounts: upstream_accounts }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.accounts(consent_id: 'consent-abc')

      expect(
        a_request(:get, 'https://priora.saltedge.com/v1/accounts').with(
          headers: {
            'Consent-ID' => 'consent-abc',
            'Signature' => 'sig'
          }
        )
      ).to have_been_made
      expect(result).to eq(upstream_accounts)
    end

    it 'returns an empty array when the response contains no accounts key' do
      stub_request(:get, 'https://priora.saltedge.com/v1/accounts')
        .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

      expect(service.accounts(consent_id: 'consent-abc')).to eq([])
    end

    it 'raises when upstream returns a non-2xx response' do
      stub_request(:get, 'https://priora.saltedge.com/v1/accounts')
        .to_return(status: 403, body: '{"tppMessages":[{"text":"CONSENT_INVALID"}]}')

      expect { service.accounts(consent_id: 'expired') }.to raise_error(SaltEdge::RequestError, 'CONSENT_INVALID')
    end
  end
end
