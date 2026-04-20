# frozen_string_literal: true

RSpec.describe SaltEdge::AccountsFetchService do
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

  subject(:service) do
    described_class.new(certificate: nil, request_adapter: request_adapter)
  end

  before do
    allow(signer).to receive(:build_headers).and_return(signed_headers)
  end

  describe '#fetch_and_persist' do
    context 'without balances' do
      before do
        stub_accounts(
          consent_id: 'consent-abc',
          accounts: [
            { 'resourceId' => 'acc-001', 'iban' => 'DE89370400440532013000', 'currency' => 'EUR', 'name' => 'Checking' },
            { 'resourceId' => 'acc-002', 'iban' => 'DE00987654321', 'currency' => 'EUR', 'name' => 'Savings' }
          ]
        )
      end

      it 'creates accounts from upstream data' do
        expect { service.fetch_and_persist(consent_id: 'consent-abc') }
          .to change(Account, :count).by(2)
      end

      it 'returns the persisted account records' do
        accounts = service.fetch_and_persist(consent_id: 'consent-abc')
        expect(accounts.map(&:resource_id)).to contain_exactly('acc-001', 'acc-002')
      end

      it 'maps upstream fields to account attributes' do
        service.fetch_and_persist(consent_id: 'consent-abc')
        account = Account.find_by(resource_id: 'acc-001')

        expect(account.iban).to eq('DE89370400440532013000')
        expect(account.currency).to eq('EUR')
        expect(account.name).to eq('Checking')
      end

      it 'upserts on second call instead of duplicating' do
        service.fetch_and_persist(consent_id: 'consent-abc')
        expect { service.fetch_and_persist(consent_id: 'consent-abc') }
          .not_to change(Account, :count)
      end

      it 'updates fields on upsert' do
        service.fetch_and_persist(consent_id: 'consent-abc')

        stub_accounts(
          consent_id: 'consent-abc',
          accounts: [
            { 'resourceId' => 'acc-001', 'iban' => 'DE89370400440532013000', 'currency' => 'EUR', 'name' => 'Updated Name' }
          ]
        )
        service.fetch_and_persist(consent_id: 'consent-abc')

        expect(Account.find_by(resource_id: 'acc-001').name).to eq('Updated Name')
      end
    end

    context 'with balances (with_balance: true)' do
      before do
        stub_accounts_from_fixture(
          consent_id: 'consent-abc',
          fixture_name: 'accounts_with_balances',
          with_balance: true
        )
      end

      it 'creates account balances' do
        expect { service.fetch_and_persist(consent_id: 'consent-abc', with_balance: true) }
          .to change(AccountBalance, :count).by(2)
      end

      it 'maps balance fields correctly' do
        service.fetch_and_persist(consent_id: 'consent-abc', with_balance: true)
        account = Account.find_by(resource_id: 'acc-001')
        balance = account.account_balances.find_by(balance_type: 'closingBooked')

        expect(balance.amount).to eq(BigDecimal('1234.56'))
        expect(balance.currency).to eq('EUR')
        expect(balance.credit_limit_included).to eq(false)
        expect(balance.reference_date).to eq(Date.new(2026, 4, 20))
      end

      it 'upserts balances on second call' do
        service.fetch_and_persist(consent_id: 'consent-abc', with_balance: true)

        stub_accounts_from_fixture(
          consent_id: 'consent-abc',
          fixture_name: 'accounts_with_balances',
          with_balance: true
        )
        expect { service.fetch_and_persist(consent_id: 'consent-abc', with_balance: true) }
          .not_to change(AccountBalance, :count)
      end
    end

    context 'when upstream returns an error' do
      before do
        stub_accounts_error(status: 403, body: { 'tppMessages' => [{ 'text' => 'CONSENT_INVALID' }] })
      end

      it 'raises SaltEdge::RequestError' do
        expect { service.fetch_and_persist(consent_id: 'expired') }
          .to raise_error(SaltEdge::RequestError, 'CONSENT_INVALID')
      end

      it 'creates no accounts' do
        expect { service.fetch_and_persist(consent_id: 'expired') rescue nil }
          .not_to change(Account, :count)
      end
    end
  end
end
