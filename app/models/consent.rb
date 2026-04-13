# frozen_string_literal: true

# == Schema Information
#
# Table name: consents
#
#  id                   :integer          not null, primary key
#  callback_error       :text
#  callback_params      :json             not null
#  callback_received_at :datetime
#  status               :string           default("received"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  provider_id          :integer          not null
#  upstream_consent_id  :string
#
# Indexes
#
#  index_consents_on_provider_id        (provider_id)
#  index_consents_on_provider_upstream  (provider_id,upstream_consent_id) UNIQUE
#
# Foreign Keys
#
#  provider_id  (provider_id => providers.id)
#
# Check Constraints
#
#  consents_status_check  (status IN ('accepted','received','valid','partiallyAuthorised','rejected','revokedByPsu','expired','terminatedByTpp'))
#
class Consent < ApplicationRecord
  STATUS_ACCEPTED = 'accepted'
  STATUS_RECEIVED = 'received'
  STATUS_VALID = 'valid'
  STATUS_PARTIALLY_AUTHORISED = 'partiallyAuthorised'
  STATUS_REJECTED = 'rejected'
  STATUS_REVOKED_BY_PSU = 'revokedByPsu'
  STATUS_EXPIRED = 'expired'
  STATUS_TERMINATED_BY_TPP = 'terminatedByTpp'

  belongs_to :provider
  has_many :events, dependent: :destroy

  enum :status,
       {
         accepted: STATUS_ACCEPTED,
         received: STATUS_RECEIVED,
         valid: STATUS_VALID,
         partially_authorised: STATUS_PARTIALLY_AUTHORISED,
         rejected: STATUS_REJECTED,
         revoked_by_psu: STATUS_REVOKED_BY_PSU,
         expired: STATUS_EXPIRED,
         terminated_by_tpp: STATUS_TERMINATED_BY_TPP
       },
       prefix: true,
       validate: true

  validates :upstream_consent_id, uniqueness: { scope: :provider_id }, allow_nil: true

  # `state` column was removed; callbacks are correlated via consent id in redirect URI.
  # Allow upstream_consent_id to be nil at creation time (set after upstream consent creation).

  def self.status_value(value)
    statuses.value?(value) ? value : STATUS_RECEIVED
  end
end
