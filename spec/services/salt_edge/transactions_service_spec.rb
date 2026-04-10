# frozen_string_literal: true

RSpec.describe SaltEdge::TransactionsService do
  let(:adapter_config) { instance_double(SaltEdge::Config, api_base_url: 'https://priora.saltedge.com', http_timeout: 30) }
  let(:signer) { instance_double(SaltEdge::SignatureBuilder) }
  let(:request_adapter) { SaltEdge::RequestAdapter.new(config: adapter_config, signer: signer, client: HTTPX) }

  subject(:service) { described_class.new(request_adapter: request_adapter) }

  let(:upstream_transactions) do
    {
      'booked' => [{ 'bookingDate' => '2026-01-15', 'transactionAmount' => { 'amount' => '-42.00', 'currency' => 'EUR' } }],
      'pending' => []
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

  describe '#transactions' do
    it 'requests the correct path with explicit dates and Consent-ID header' do
      stub_request(:get, 'https://priora.saltedge.com/v1/accounts/acc-001/transactions?bookingStatus=both&dateFrom=2026-01-01&dateTo=2026-01-31')
        .to_return(status: 200, body: { transactions: upstream_transactions }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.transactions(
        account_id: 'acc-001',
        consent_id: 'consent-abc',
        date_from: Date.new(2026, 1, 1),
        date_to: Date.new(2026, 1, 31)
      )

      expect(
        a_request(:get, 'https://priora.saltedge.com/v1/accounts/acc-001/transactions?bookingStatus=both&dateFrom=2026-01-01&dateTo=2026-01-31').with(
          headers: {
            'Consent-ID' => 'consent-abc',
            'Signature' => 'sig'
          }
        )
      ).to have_been_made
      expect(result).to eq(upstream_transactions)
    end

    it 'accepts a custom booking_status' do
      stub_request(:get, 'https://priora.saltedge.com/v1/accounts/acc-001/transactions?bookingStatus=booked&dateFrom=2026-01-01&dateTo=2026-01-31')
        .to_return(status: 200, body: { transactions: upstream_transactions }.to_json, headers: { 'Content-Type' => 'application/json' })

      service.transactions(
        account_id: 'acc-001',
        consent_id: 'consent-abc',
        date_from: Date.new(2026, 1, 1),
        date_to: Date.new(2026, 1, 31),
        booking_status: 'booked'
      )

      expect(a_request(:get, 'https://priora.saltedge.com/v1/accounts/acc-001/transactions?bookingStatus=booked&dateFrom=2026-01-01&dateTo=2026-01-31')).to have_been_made.once
    end

    it 'defaults date_to to today and date_from to 30 days earlier' do
      today = Date.new(2026, 4, 10)
      allow(Date).to receive(:current).and_return(today)
      stub_request(:get, 'https://priora.saltedge.com/v1/accounts/acc-001/transactions?bookingStatus=both&dateFrom=2026-03-11&dateTo=2026-04-10')
        .to_return(status: 200, body: { transactions: upstream_transactions }.to_json, headers: { 'Content-Type' => 'application/json' })

      service.transactions(account_id: 'acc-001', consent_id: 'consent-abc')

      expect(a_request(:get, 'https://priora.saltedge.com/v1/accounts/acc-001/transactions?bookingStatus=both&dateFrom=2026-03-11&dateTo=2026-04-10')).to have_been_made.once
    end

    it 'returns an empty hash when the response contains no transactions key' do
      stub_request(:get, /https:\/\/priora\.saltedge\.com\/v1\/accounts\/acc-001\/transactions\?.*/)
        .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

      expect(service.transactions(account_id: 'acc-001', consent_id: 'consent-abc')).to eq({})
    end

    it 'raises when upstream returns a non-2xx response' do
      stub_request(:get, /https:\/\/priora\.saltedge\.com\/v1\/accounts\/acc-001\/transactions\?.*/)
        .to_return(status: 401, body: '{"tppMessages":[{"text":"CONSENT_EXPIRED"}]}')

      expect {
        service.transactions(account_id: 'acc-001', consent_id: 'expired')
      }.to raise_error(SaltEdge::RequestError, 'CONSENT_EXPIRED')
    end

    it 'URL-encodes the account_id in the path' do
      stub_request(:get, 'https://priora.saltedge.com/v1/accounts/acc%2Fweird+id/transactions?bookingStatus=both&dateFrom=2026-01-01&dateTo=2026-01-31')
        .to_return(status: 200, body: { transactions: upstream_transactions }.to_json, headers: { 'Content-Type' => 'application/json' })

      service.transactions(
        account_id: 'acc/weird id',
        consent_id: 'consent-abc',
        date_from: Date.new(2026, 1, 1),
        date_to: Date.new(2026, 1, 31)
      )

      expect(a_request(:get, 'https://priora.saltedge.com/v1/accounts/acc%2Fweird+id/transactions?bookingStatus=both&dateFrom=2026-01-01&dateTo=2026-01-31')).to have_been_made.once
    end
  end
end
