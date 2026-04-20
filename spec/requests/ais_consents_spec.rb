# frozen_string_literal: true

RSpec.describe 'AisConsents', type: :request do
  # Use the real ConsentService in request specs; stub its dependencies (Config and Signer)
  let(:consent_service) { nil }

  before do
    Flipper.enable(:ais_event_recording)
    # Provide a test config to the real service so it does not read real ENV
    cfg = instance_double(SaltEdge::Config, api_base_url: 'https://priora.saltedge.com', callback_base_url: 'https://example.test', api_provider_code: 'artea_sandbox', psu_ip_address: '9.9.9.9', http_timeout: 5)
    allow(SaltEdge::Config).to receive(:new).and_return(cfg)

    # Stub signer to avoid requiring real qseal artifacts
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
    # Note: accounts/transactions fetching is covered by dedicated controller specs.
  end

  describe 'consent creation endpoints' do
    it 'creates provider/consent records via POST /ais/consents and redirects to SCA URL' do
      company = create(:company)
      user = create(:user)
      stub_create_consent(consent_id: 'consent-123', consent_status: 'received', sca_url: 'https://aspsp.example/sca')

      post ais_consents_path, params: { provider: { name: 'Artea Sandbox', code: 'artea_sandbox', company_id: company.id, representative_id: user.id } }

      expect(response).to redirect_to('https://aspsp.example/sca')
      consent = Consent.order(:created_at).last
      expect(consent.upstream_consent_id).to eq('consent-123')
      expect(consent.status).to eq('received')
      expect(consent.provider).to be_present
      expect(consent.events.where(event_type: 'consent_create').count).to eq(1)
    end
  end

  describe 'GET /callback' do
    it 'rejects unsupported callback event types' do
      provider = create(:provider)
      consent = provider.consents.create!(upstream_consent_id: 'consent-123', status: Consent::STATUS_RECEIVED)

      get ais_callback_path(consent), params: { event_type: 'unknown_event' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)).to eq('error' => 'unsupported_event_type', 'event_type' => 'unknown_event')
      event = consent.events.order(:created_at).last
      expect(event.event_type).to eq('callback')
      expect(event.request_body).to include('consent_id' => consent.id, 'event_type' => 'unknown_event')
      expect(event.response_body).to include('error' => 'unsupported_event_type')
    end

    it 'rejects missing consent id in callback URL' do
      get '/callback'

      expect(response).to have_http_status(:not_found)
    end

    it 'returns unprocessable_content when the consent has no upstream id yet' do
      provider = create(:provider)
      consent = provider.consents.create!(upstream_consent_id: nil, status: Consent::STATUS_RECEIVED, callback_params: {})

      get ais_callback_path(consent), params: { code: 'auth-code' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)).to include('error' => 'missing_upstream_consent_id')

      event = consent.events.order(:created_at).last
      expect(event).to be_present
      expect(event.event_type).to eq('callback')
      expect(event.response_body).to include('error' => 'missing_upstream_consent_id')
    end

    it 'rejects replayed callback payloads' do
      provider = create(:provider)
      consent = provider.consents.create!(upstream_consent_id: 'consent-123', status: Consent::STATUS_RECEIVED)
      Event.create!(
        provider: provider,
        consent: consent,
        event_type: 'replay_marker',
        request_body: Event.callback_payload(consent_id: consent.id, code: 'replay-code'),
        occurred_at: Time.now.utc
      )

      get ais_callback_path(consent), params: { code: 'replay-code' }

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)).to eq('error' => 'state_replay')
      # CallbackProcessor records a single incoming 'callback' Event with the replay error
      event = consent.events.order(:created_at).last
      expect(event.event_type).to eq('callback')
      expect(event.response_body).to include('error' => 'state_replay')
      expect(consent.events.where(event_type: 'replay_detected').count).to eq(0)
    end

    it 'persists callback and redirects to result when consent is valid' do
      company = create(:company)
      user = create(:user)
      stub_create_consent(consent_id: 'consent-123', consent_status: 'received', sca_url: 'https://aspsp.example/sca')

      post ais_consents_path, params: { provider: { name: 'Artea Sandbox', code: 'artea_sandbox', company_id: company.id, representative_id: user.id } }

      consent = Consent.order(:created_at).last
      accounts = [{ 'resourceId' => 'acc-1', 'iban' => 'DE123' }]
      tx = { 'booked' => [{ 'transactionId' => 'tx-1' }] }

      stub_consent_status('consent-123', 'valid')

      get ais_callback_path(consent), params: { code: 'auth-code' }

      expect(response).to redirect_to(ais_consent_path(consent))
      consent.reload
      expect(consent.callback_received_at).to be_present
      expect(consent.callback_params).to eq('code' => 'auth-code')
      expect(consent.status).to eq('valid')
      # CallbackProcessor records a single incoming 'callback' Event; data fetching is manual.
      expect(consent.events.where(event_type: 'callback').count).to eq(1)
      expect(consent.events.where(event_type: 'consent_status_check').count).to eq(1)

      # Data fetching is validated in dedicated controller specs.
    end

    it 'allows partially authorised progression before valid' do
      company = create(:company)
      user = create(:user)
      stub_create_consent(consent_id: 'consent-123', consent_status: 'received', sca_url: 'https://aspsp.example/sca')

      post ais_consents_path, params: { provider: { name: 'Artea Sandbox', code: 'artea_sandbox', company_id: company.id, representative_id: user.id } }

      consent = Consent.order(:created_at).last
      stub_consent_status('consent-123', ['partiallyAuthorised', 'valid'])

      get ais_callback_path(consent), params: { code: 'step-1' }
      expect(response).to have_http_status(:forbidden)
      expect(consent.reload.status_before_type_cast).to eq('partiallyAuthorised')
      # After first step, one incoming callback event and one consent_status_check
      expect(consent.events.where(event_type: 'callback').count).to eq(1)
      expect(consent.events.where(event_type: 'consent_status_check').count).to eq(1)

      get ais_callback_path(consent), params: { code: 'step-2' }
      expect(response).to redirect_to(ais_consent_path(consent))
      expect(consent.reload.status).to eq('valid')
      # After second step, another incoming callback; fetches are manual
      expect(consent.events.where(event_type: 'callback').count).to eq(2)
      expect(consent.events.where(event_type: 'consent_status_check').count).to eq(2)

      # Data fetching is validated in dedicated controller specs.
    end
  end
end
