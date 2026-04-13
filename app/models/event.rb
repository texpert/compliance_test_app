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
class Event < ApplicationRecord
  belongs_to :provider, optional: true
  belongs_to :consent, optional: true

  validates :event_type, presence: true
  validates :occurred_at, presence: true

  def self.record(event_type:, provider: nil, consent: nil, request_headers: {}, request_body: {}, response_headers: {}, response_body: {})
    return unless Flipper.enabled?(:ais_event_recording)

    create(
      provider: provider || consent&.provider,
      consent: consent,
      event_type: event_type,
      request_headers: request_headers || {},
      request_body: request_body || {},
      response_headers: response_headers || {},
      response_body: response_body || {},
      occurred_at: Time.now.utc
    )
  end

  # Build a standardized callback payload. New flow uses consent_id instead of state.
  def self.callback_payload(consent_id: nil, state: nil, code: nil)
    payload = {}
    payload['consent_id'] = consent_id.to_s if consent_id.present?
    payload['state'] = state.to_s if state.present?
    payload['code'] = code.to_s.presence
    payload
  end

  def self.callback_replayed?(consent:, consent_id: nil, state: nil, code: nil)
    where(event_type: 'replay_marker', consent: consent, request_body: callback_payload(consent_id: consent_id, state: state, code: code)).exists?
  end
end
