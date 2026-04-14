# frozen_string_literal: true

RSpec.describe 'AisAccounts', type: :request do
  let(:accounts_service) { instance_double(SaltEdge::AccountsService) }
  let(:company) { create(:company) }
  let(:user) { create(:user) }
  let(:provider) { create(:provider, company: company, representative: user) }

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
  end

  it 'returns accounts and records an accounts_fetch Event' do
    consent = provider.consents.create!(upstream_consent_id: 'consent-1', status: Consent::STATUS_VALID)

    accounts = [{ 'resourceId' => 'acc-1', 'iban' => 'DE123' }]
    allow(accounts_service).to receive(:accounts).with(consent_id: 'consent-1').and_return(accounts)

    get ais_consent_accounts_path(consent)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq('accounts' => accounts)

    consent.reload
    expect(consent.events.where(event_type: 'accounts_fetch').count).to eq(1)
    last = consent.events.order(:created_at).last
    expect(last.response_body).to include('accounts' => accounts)
  end

  it 'returns not_found when consent does not exist' do
    get '/ais/consents/99999/accounts'
    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)).to include('error' => 'consent_not_found')
  end

  it 'returns forbidden when consent status is not valid' do
    consent = provider.consents.create!(upstream_consent_id: 'consent-1', status: Consent::STATUS_RECEIVED)

    get ais_consent_accounts_path(consent)

    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body)).to include('error' => 'consent_not_valid', 'consent_status' => 'received')
  end

  it 'records upstream error and returns bad_gateway' do
    consent = provider.consents.create!(upstream_consent_id: 'consent-1', status: Consent::STATUS_VALID)

    allow(accounts_service).to receive(:accounts).and_raise(SaltEdge::RequestError.new('upstream failure'))

    get ais_consent_accounts_path(consent)

    expect(response).to have_http_status(:bad_gateway)
    consent.reload
    last = consent.events.order(:created_at).last
    expect(last.event_type).to eq('accounts_fetch')
    expect(last.response_body).to include('error' => 'upstream_error')
    expect(last.response_body['message']).to include('upstream failure')
  end
end
