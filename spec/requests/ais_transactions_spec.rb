# frozen_string_literal: true

RSpec.describe 'AisTransactions', type: :request do
  let(:accounts_service) { instance_double(SaltEdge::AccountsService) }
  let(:transactions_service) { instance_double(SaltEdge::TransactionsService) }

  before do
    Flipper.enable(:ais_event_recording)
    cfg = instance_double(SaltEdge::Config, api_base_url: 'https://priora.saltedge.com', redirect_uri: 'https://example.test/callback', psu_ip_address: '9.9.9.9', http_timeout: 5)
    allow(SaltEdge::Config).to receive(:new).and_return(cfg)

    signer = instance_double(SaltEdge::SignatureBuilder)
    signed_headers = {
      'Signature' => 'sig',
      'Digest' => 'SHA-256=abc',
      'X-Request-ID' => 'request-1',
      'Date' => 'Fri, 10 Apr 2026 12:00:00 GMT',
      'TPP-Signature-Certificate' => 'cert'
    }
    allow(SaltEdge::SignatureBuilder).to receive(:new).and_return(signer)
    allow(signer).to receive(:build_headers).and_return(signed_headers)

    allow(SaltEdge::AccountsService).to receive(:new).and_return(accounts_service)
    allow(SaltEdge::TransactionsService).to receive(:new).and_return(transactions_service)
  end

  it 'returns not_found when consent does not exist' do
    get '/ais/consents/99999/accounts/acc-x/transactions'
    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)).to include('error' => 'consent_not_found')
  end

  it 'returns forbidden when consent status is not valid' do
    company = Company.create!(name: 'Test Company', email: 'test@company.com', address: '123 Main St', phone_number: '+1234567890', zip_code: '12345', city: 'Testville', country_code: 'US')
    user = User.create!(name: 'Test User', email: 'user@company.com')
    provider = Provider.create!(name: 'Artea Sandbox', code: 'artea_sandbox', company: company, representative: user)
    consent = provider.consents.create!(upstream_consent_id: 'consent-1', status: Consent::STATUS_RECEIVED)

    get ais_consent_account_transactions_path(consent, 'acc-1')

    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body)).to include('error' => 'consent_not_valid', 'consent_status' => 'received')
  end

  it 'returns transactions for a given account and records transactions_fetch Event' do
    company = Company.create!(name: 'Test Company', email: 'test@company.com', address: '123 Main St', phone_number: '+1234567890', zip_code: '12345', city: 'Testville', country_code: 'US')
    user = User.create!(name: 'Test User', email: 'user@company.com')
    provider = Provider.create!(name: 'Artea Sandbox', code: 'artea_sandbox', company: company, representative: user)
    consent = provider.consents.create!(upstream_consent_id: 'consent-1', status: Consent::STATUS_VALID)

    tx = { 'booked' => [{ 'transactionId' => 'tx-1' }] }
    allow(transactions_service).to receive(:transactions).with(account_id: 'acc-1', consent_id: 'consent-1').and_return(tx)

    get ais_consent_account_transactions_path(consent, 'acc-1')

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq('transactions' => tx)

    consent.reload
    expect(consent.events.where(event_type: 'transactions_fetch').count).to eq(1)
    last = consent.events.order(:created_at).last
    expect(last.response_body).to include('transactions' => tx)
  end

  it 'returns no_account_available when no account can be derived' do
    company = Company.create!(name: 'Test Company', email: 'test@company.com', address: '123 Main St', phone_number: '+1234567890', zip_code: '12345', city: 'Testville', country_code: 'US')
    user = User.create!(name: 'Test User', email: 'user@company.com')
    provider = Provider.create!(name: 'Artea Sandbox', code: 'artea_sandbox', company: company, representative: user)
    consent = provider.consents.create!(upstream_consent_id: 'consent-1', status: Consent::STATUS_VALID)

    allow(accounts_service).to receive(:accounts).with(consent_id: 'consent-1').and_return([])

    # call the consent-level transactions endpoint to trigger derivation path
    get ais_consent_transactions_path(consent)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)).to include('error' => 'no_account_available')
    consent.reload
    expect(consent.events.where(event_type: 'transactions_fetch').count).to eq(0)
  end

  it 'records upstream error and returns bad_gateway' do
    company = Company.create!(name: 'Test Company', email: 'test@company.com', address: '123 Main St', phone_number: '+1234567890', zip_code: '12345', city: 'Testville', country_code: 'US')
    user = User.create!(name: 'Test User', email: 'user@company.com')
    provider = Provider.create!(name: 'Artea Sandbox', code: 'artea_sandbox', company: company, representative: user)
    consent = provider.consents.create!(upstream_consent_id: 'consent-1', status: Consent::STATUS_VALID)

    allow(transactions_service).to receive(:transactions).and_raise(SaltEdge::RequestError.new('timeout'))

    get ais_consent_account_transactions_path(consent, 'acc-1')

    expect(response).to have_http_status(:bad_gateway)
    consent.reload
    last = consent.events.order(:created_at).last
    expect(last.event_type).to eq('transactions_fetch')
    expect(last.response_body).to include('error' => 'upstream_error')
    expect(last.response_body['message']).to include('timeout')
  end
end
