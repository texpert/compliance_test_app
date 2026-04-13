# frozen_string_literal: true

# == Schema Information
#
# Table name: events
#
#  id               :integer          not null, primary key
#  event_type       :string           not null
#  occurred_at      :datetime         not null
#  request_body     :json             not null
#  request_headers  :json             not null
#  response_body    :json             not null
#  response_headers :json             not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  consent_id       :integer
#  provider_id      :integer
#
# Indexes
#
#  index_events_on_consent_id   (consent_id)
#  index_events_on_event_type   (event_type)
#  index_events_on_occurred_at  (occurred_at)
#  index_events_on_provider_id  (provider_id)
#
# Foreign Keys
#
#  consent_id   (consent_id => consents.id)
#  provider_id  (provider_id => providers.id)
#
RSpec.describe Event, type: :model do
  let(:provider) { Provider.create!(name: 'Artea Sandbox', code: 'artea_sandbox') }
  let(:consent) { provider.consents.create!(upstream_consent_id: 'consent-1', status: Consent::STATUS_RECEIVED) }

  before { Flipper.enable(:ais_event_recording) }

  it 'persists structured request/response snapshots when feature flag is enabled' do
    event = described_class.record(
      provider: provider,
      consent: consent,
      event_type: 'consent_status_check',
      request_headers: { 'X-Request-ID' => 'req-1' },
      request_body: { consent_id: 'consent-1' },
      response_headers: { 'Content-Type' => 'application/json' },
      response_body: { consent_status: 'valid' }
    )

    expect(event).to be_persisted
    expect(event.occurred_at).to be_present
    expect(event.request_headers).to eq('X-Request-ID' => 'req-1')
    expect(event.response_body).to eq('consent_status' => 'valid')
  end

  it 'does not persist when feature flag is disabled' do
    Flipper.disable(:ais_event_recording)

    expect do
      result = described_class.record(event_type: 'accounts_fetch', provider: provider, request_body: { consent_id: 'consent-1' })
      expect(result).to be_nil
    end.not_to change(described_class, :count)
  ensure
    Flipper.enable(:ais_event_recording)
  end

  describe '.callback_replayed?' do
    it 'returns false when no replay_marker exists for the given consent_id and code' do
      expect(described_class.callback_replayed?(consent: consent, consent_id: consent.id, code: 'code-1')).to be false
    end

    it 'returns true when a replay_marker exists for the given consent_id and code' do
      described_class.create!(
        provider: provider,
        consent: consent,
        event_type: 'replay_marker',
        request_body: described_class.callback_payload(consent_id: consent.id, code: 'code-1'),
        occurred_at: Time.now.utc
      )

      expect(described_class.callback_replayed?(consent: consent, consent_id: consent.id, code: 'code-1')).to be true
    end

    it 'does not trigger on callback_received events with the same payload' do
      described_class.create!(
        provider: provider,
        consent: consent,
        event_type: 'callback_received',
        request_body: described_class.callback_payload(consent_id: consent.id, code: 'code-1'),
        occurred_at: Time.now.utc
      )

      expect(described_class.callback_replayed?(consent: consent, consent_id: consent.id, code: 'code-1')).to be false
    end
  end
end
