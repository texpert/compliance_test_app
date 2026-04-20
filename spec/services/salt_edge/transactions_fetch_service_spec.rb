# frozen_string_literal: true

RSpec.describe SaltEdge::TransactionsFetchService do
  let(:adapter_config) { instance_double(SaltEdge::Config, api_base_url: 'https://priora.saltedge.com', http_timeout: 30) }
  let(:signer) { instance_double(SaltEdge::SignatureBuilder) }
  let(:request_adapter) { SaltEdge::RequestAdapter.new(config: adapter_config, signer: signer, client: HTTPX) }
  let(:signed_headers) do
    {
      'Signature' => 'sig',
      'Digest' => 'SHA-256=abc',
      'X-Request-ID' => 'req-1',
      'Date' => 'Fri, 10 Apr 2026 12:00:00 GMT',
      'TPP-Signature-Certificate' => 'cert'
    }
  end
  let(:account) { create(:account, resource_id: 'acc-001', currency: 'EUR') }

  subject(:service) do
    described_class.new(certificate: nil, request_adapter: request_adapter)
  end

  before do
    allow(signer).to receive(:build_headers).and_return(signed_headers)
  end

  describe '#fetch_and_persist' do
    context 'with booked and pending transactions' do
      before do
        stub_transactions_from_fixture(
          account_id: 'acc-001',
          consent_id: 'consent-abc',
          fixture_name: 'transactions_with_details'
        )
      end

      it 'creates booked and pending transaction records' do
        expect {
          service.fetch_and_persist(account: account, consent_id: 'consent-abc')
        }.to change(Transaction, :count).by(3)
      end

      it 'returns the count of persisted transactions' do
        expect(service.fetch_and_persist(account: account, consent_id: 'consent-abc')).to eq(3)
      end

      it 'maps booked transaction fields correctly' do
        service.fetch_and_persist(account: account, consent_id: 'consent-abc')
        tx = Transaction.find_by(transaction_id: 'tx-001')

        expect(tx.booking_status).to eq('booked')
        expect(tx.booking_date).to eq(Date.new(2026, 1, 15))
        expect(tx.value_date).to eq(Date.new(2026, 1, 16))
        expect(tx.amount).to eq(BigDecimal('-42.50'))
        expect(tx.currency).to eq('EUR')
        expect(tx.creditor_name).to eq('SuperMarket GmbH')
        expect(tx.creditor_iban).to eq('DE12345678901234567890')
        expect(tx.remittance_information_unstructured).to eq('Grocery shopping')
        expect(tx.proprietary_bank_transaction_code).to eq('PMNT')
      end

      it 'marks pending transactions correctly' do
        service.fetch_and_persist(account: account, consent_id: 'consent-abc')
        pending_tx = Transaction.where(booking_status: 'pending').first

        expect(pending_tx.creditor_name).to eq('Online Shop')
        expect(pending_tx.amount).to eq(BigDecimal('-19.99'))
        expect(pending_tx.transaction_id).to be_nil
      end
    end

    context 'upsert behaviour for booked transactions' do
      before do
        stub_transactions(
          account_id: 'acc-001',
          consent_id: 'consent-abc',
          transactions: {
            'booked' => [
              { 'transactionId' => 'tx-001', 'bookingDate' => '2026-01-15',
                'transactionAmount' => { 'amount' => '-42.50', 'currency' => 'EUR' } }
            ],
            'pending' => []
          }
        )
      end

      it 'does not duplicate booked transactions on second fetch' do
        service.fetch_and_persist(account: account, consent_id: 'consent-abc')
        expect {
          service.fetch_and_persist(account: account, consent_id: 'consent-abc')
        }.not_to change(Transaction, :count)
      end

      it 'updates booked transaction fields on re-fetch' do
        service.fetch_and_persist(account: account, consent_id: 'consent-abc')

        stub_transactions(
          account_id: 'acc-001',
          consent_id: 'consent-abc',
          transactions: {
            'booked' => [
              { 'transactionId' => 'tx-001', 'bookingDate' => '2026-01-15',
                'transactionAmount' => { 'amount' => '-42.50', 'currency' => 'EUR' },
                'creditorName' => 'Updated Merchant' }
            ],
            'pending' => []
          }
        )
        service.fetch_and_persist(account: account, consent_id: 'consent-abc')

        expect(Transaction.find_by(transaction_id: 'tx-001').creditor_name).to eq('Updated Merchant')
      end
    end

    context 'pending transaction replacement' do
      let(:pending_tx_data) do
        { 'bookingDate' => '2026-01-20',
          'transactionAmount' => { 'amount' => '-10.00', 'currency' => 'EUR' } }
      end

      before do
        create(:transaction, :pending, account: account)
        stub_transactions(
          account_id: 'acc-001',
          consent_id: 'consent-abc',
          transactions: { 'booked' => [], 'pending' => [pending_tx_data] }
        )
      end

      it 'replaces existing pending transactions' do
        expect {
          service.fetch_and_persist(account: account, consent_id: 'consent-abc')
        }.not_to change { Transaction.where(booking_status: 'pending').count }
      end
    end

    context 'when booking_status is booked only' do
      before do
        stub_transactions(
          account_id: 'acc-001',
          consent_id: 'consent-abc',
          transactions: {
            'booked' => [
              { 'transactionId' => 'tx-001', 'transactionAmount' => { 'amount' => '-5.00', 'currency' => 'EUR' } }
            ]
          }
        )
      end

      it 'creates only booked transactions' do
        service.fetch_and_persist(account: account, consent_id: 'consent-abc', booking_status: 'booked')
        expect(Transaction.where(booking_status: 'booked').count).to eq(1)
        expect(Transaction.where(booking_status: 'pending').count).to eq(0)
      end
    end

    context 'when upstream returns an error' do
      before do
        stub_transactions_error(account_id: 'acc-001', status: 401,
                                body: { 'tppMessages' => [{ 'text' => 'CONSENT_EXPIRED' }] })
      end

      it 'raises SaltEdge::RequestError' do
        expect {
          service.fetch_and_persist(account: account, consent_id: 'expired')
        }.to raise_error(SaltEdge::RequestError, 'CONSENT_EXPIRED')
      end

      it 'creates no transactions' do
        expect {
          service.fetch_and_persist(account: account, consent_id: 'expired') rescue nil
        }.not_to change(Transaction, :count)
      end
    end

    context 'when paginated is true' do
      let(:page1) { { 'booked' => [{ 'transactionId' => 'tx-p1', 'transactionAmount' => { 'amount' => '-8.00', 'currency' => 'EUR' } }], 'pending' => [] } }
      let(:page2) { { 'booked' => [{ 'transactionId' => 'tx-p2', 'transactionAmount' => { 'amount' => '-15.00', 'currency' => 'EUR' } }], 'pending' => [] } }

      before do
        stub_paginated_transactions(
          account_id: 'acc-001',
          consent_id: 'consent-abc',
          pages: [page1, page2]
        )
      end

      it 'includes paginated=1 in the initial request URL and follows the next page' do
        service.fetch_and_persist(account: account, consent_id: 'consent-abc',
                                  date_from: Date.new(2026, 1, 1), date_to: Date.new(2026, 1, 31),
                                  paginated: true)

        expect(a_request(:get, /paginated=1/)).to have_been_made.twice
      end

      it 'persists transactions from all pages' do
        expect {
          service.fetch_and_persist(account: account, consent_id: 'consent-abc',
                                    date_from: Date.new(2026, 1, 1), date_to: Date.new(2026, 1, 31),
                                    paginated: true)
        }.to change(Transaction, :count).by(2)
      end
    end
  end
end
