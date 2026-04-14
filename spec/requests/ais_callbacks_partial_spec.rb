# frozen_string_literal: true

RSpec.describe 'AisCallbacks partial progression', type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user) }
  let(:provider) { create(:provider, company: company, representative: user) }
  let(:consent_service) { instance_double(SaltEdge::ConsentService) }

  before do
    Flipper.enable(:ais_event_recording)
    allow(SaltEdge::ConsentService).to receive(:new).and_return(consent_service)
  end

  it 'allows progression when replay marker exists and consent is partiallyAuthorised' do
    consent = provider.consents.create!(upstream_consent_id: 'consent-123', status: Consent::STATUS_PARTIALLY_AUTHORISED, callback_params: {})

    # Insert a replay marker for the same consent/code
    Event.create!(provider: provider, consent: consent, event_type: 'replay_marker', request_body: Event.callback_payload(consent_id: consent.id, code: 'replay-code'), occurred_at: Time.now.utc)

    allow(consent_service).to receive(:consent_status).with('consent-123').and_return('valid')

    get ais_callback_path(consent), params: { code: 'replay-code' }

    expect(response).to redirect_to(ais_consent_path(consent))
    consent.reload
    expect(consent.status).to eq('valid')

    # A single incoming callback Event should be recorded for this request
    expect(consent.events.where(event_type: 'callback').count).to be >= 1
    # No separate 'replay_detected' event should be recorded; handler allows progression for partiallyAuthorised
    expect(consent.events.where(event_type: 'replay_detected').count).to eq(0)
  end
end
