# frozen_string_literal: true

RSpec.describe 'AisCallbacks replay rejection', type: :request do
  before { Flipper.enable(:ais_event_recording) }

  it 'rejects replay when consent is not partiallyAuthorised' do
    company = Company.create!(name: 'Test Company', email: 'test@company.com', address: '123 Main St', phone_number: '+1234567890', zip_code: '12345', city: 'Testville', country_code: 'US')
    user = User.create!(name: 'Test User', email: 'user@company.com')
    provider = Provider.create!(name: 'Artea Sandbox', code: 'artea_sandbox', company: company, representative: user)
    consent = provider.consents.create!(upstream_consent_id: 'consent-999', status: Consent::STATUS_RECEIVED, callback_params: {})

    # Insert a replay marker for the same consent/code
    Event.create!(provider: provider, consent: consent, event_type: 'replay_marker', request_body: Event.callback_payload(consent_id: consent.id, code: 'dup-code'), occurred_at: Time.now.utc)

    get ais_callback_path(consent), params: { code: 'dup-code' }

    expect(response).to have_http_status(:conflict)
    expect(JSON.parse(response.body)).to eq('error' => 'state_replay')

    event = consent.events.order(:created_at).last
    expect(event.event_type).to eq('callback')
    expect(event.response_body).to include('error' => 'state_replay')
  end
end
