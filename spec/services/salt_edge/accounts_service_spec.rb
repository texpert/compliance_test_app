# frozen_string_literal: true

RSpec.describe SaltEdge::AccountsService do
  let(:request_adapter) { instance_double(SaltEdge::RequestAdapter) }

  subject(:service) { described_class.new(request_adapter: request_adapter) }

  describe '#accounts' do
    let(:upstream_accounts) do
      [
        { 'resourceId' => 'acc-001', 'iban' => 'DE00123456789', 'currency' => 'EUR', 'name' => 'Checking' },
        { 'resourceId' => 'acc-002', 'iban' => 'DE00987654321', 'currency' => 'EUR', 'name' => 'Savings' }
      ]
    end

    it 'requests GET /v1/accounts with Consent-ID header' do
      allow(request_adapter).to receive(:request).and_return(
        SaltEdge::RequestResult.new(status: 200, data: { 'accounts' => upstream_accounts })
      )

      result = service.accounts(consent_id: 'consent-abc')

      expect(request_adapter).to have_received(:request).with(
        method: :get,
        path: '/v1/accounts',
        headers: { 'Consent-ID' => 'consent-abc' }
      )
      expect(result).to eq(upstream_accounts)
    end

    it 'returns an empty array when the response contains no accounts key' do
      allow(request_adapter).to receive(:request).and_return(
        SaltEdge::RequestResult.new(status: 200, data: {})
      )

      expect(service.accounts(consent_id: 'consent-abc')).to eq([])
    end

    it 'raises when the adapter returns a failure result' do
      error = SaltEdge::RequestError.new('CONSENT_INVALID', status: 403)
      allow(request_adapter).to receive(:request).and_return(
        SaltEdge::RequestResult.new(status: 403, error: error)
      )

      expect { service.accounts(consent_id: 'expired') }.to raise_error(SaltEdge::RequestError, 'CONSENT_INVALID')
    end
  end
end
