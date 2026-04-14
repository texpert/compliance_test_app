# frozen_string_literal: true

RSpec.describe 'AisCallbacks replay rejection', type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user) }
  let(:provider) { create(:provider, company: company, representative: user) }

  before { Flipper.enable(:ais_event_recording) }

  it 'rejects replay when consent is not partiallyAuthorised' do
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
