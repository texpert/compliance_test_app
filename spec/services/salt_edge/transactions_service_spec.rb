# frozen_string_literal: true

RSpec.describe SaltEdge::TransactionsService do
  let(:request_adapter) { instance_double(SaltEdge::RequestAdapter) }

  subject(:service) { described_class.new(request_adapter: request_adapter) }

  let(:upstream_transactions) do
    {
      'booked'  => [{ 'bookingDate' => '2026-01-15', 'transactionAmount' => { 'amount' => '-42.00', 'currency' => 'EUR' } }],
      'pending' => []
    }
  end

  describe '#transactions' do
    it 'requests the correct path with explicit dates and Consent-ID header' do
      allow(request_adapter).to receive(:request).and_return(
        SaltEdge::RequestResult.new(status: 200, data: { 'transactions' => upstream_transactions })
      )

      result = service.transactions(
        account_id:  'acc-001',
        consent_id:  'consent-abc',
        date_from:   Date.new(2026, 1, 1),
        date_to:     Date.new(2026, 1, 31)
      )

      expect(request_adapter).to have_received(:request).with(
        method: :get,
        path: '/v1/accounts/acc-001/transactions?bookingStatus=both&dateFrom=2026-01-01&dateTo=2026-01-31',
        headers: { 'Consent-ID' => 'consent-abc' }
      )
      expect(result).to eq(upstream_transactions)
    end

    it 'accepts a custom booking_status' do
      allow(request_adapter).to receive(:request).and_return(
        SaltEdge::RequestResult.new(status: 200, data: { 'transactions' => upstream_transactions })
      )

      service.transactions(
        account_id:    'acc-001',
        consent_id:    'consent-abc',
        date_from:     Date.new(2026, 1, 1),
        date_to:       Date.new(2026, 1, 31),
        booking_status: 'booked'
      )

      expect(request_adapter).to have_received(:request).with(
        hash_including(path: '/v1/accounts/acc-001/transactions?bookingStatus=booked&dateFrom=2026-01-01&dateTo=2026-01-31')
      )
    end

    it 'defaults date_to to today and date_from to 30 days earlier' do
      today = Date.new(2026, 4, 10)
      allow(Date).to receive(:current).and_return(today)
      allow(request_adapter).to receive(:request).and_return(
        SaltEdge::RequestResult.new(status: 200, data: { 'transactions' => upstream_transactions })
      )

      service.transactions(account_id: 'acc-001', consent_id: 'consent-abc')

      expect(request_adapter).to have_received(:request).with(
        hash_including(path: '/v1/accounts/acc-001/transactions?bookingStatus=both&dateFrom=2026-03-11&dateTo=2026-04-10')
      )
    end

    it 'returns an empty hash when the response contains no transactions key' do
      allow(request_adapter).to receive(:request).and_return(
        SaltEdge::RequestResult.new(status: 200, data: {})
      )

      expect(service.transactions(account_id: 'acc-001', consent_id: 'consent-abc')).to eq({})
    end

    it 'raises when the adapter returns a failure result' do
      error = SaltEdge::RequestError.new('CONSENT_EXPIRED', status: 401)
      allow(request_adapter).to receive(:request).and_return(
        SaltEdge::RequestResult.new(status: 401, error: error)
      )

      expect {
        service.transactions(account_id: 'acc-001', consent_id: 'expired')
      }.to raise_error(SaltEdge::RequestError, 'CONSENT_EXPIRED')
    end

    it 'URL-encodes the account_id in the path' do
      allow(request_adapter).to receive(:request).and_return(
        SaltEdge::RequestResult.new(status: 200, data: { 'transactions' => upstream_transactions })
      )

      service.transactions(
        account_id: 'acc/weird id',
        consent_id: 'consent-abc',
        date_from:  Date.new(2026, 1, 1),
        date_to:    Date.new(2026, 1, 31)
      )

      expect(request_adapter).to have_received(:request).with(
        hash_including(path: %r{/v1/accounts/acc%2Fweird\+id/transactions})
      )
    end
  end
end
