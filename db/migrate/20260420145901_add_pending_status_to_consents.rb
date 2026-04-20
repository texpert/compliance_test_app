# frozen_string_literal: true

class AddPendingStatusToConsents < ActiveRecord::Migration[8.1]
  CONSENT_STATUSES_WITH_PENDING = %w[
    pending
    accepted
    received
    valid
    partiallyAuthorised
    rejected
    revokedByPsu
    expired
    terminatedByTpp
  ].freeze

  CONSENT_STATUSES_WITHOUT_PENDING = (CONSENT_STATUSES_WITH_PENDING - %w[pending]).freeze

  def up
    remove_check_constraint :consents, name: 'consents_status_check'
    change_column_default :consents, :status, from: 'received', to: 'pending'
    add_check_constraint :consents,
                         "status IN ('#{CONSENT_STATUSES_WITH_PENDING.join("','")}')",
                         name: 'consents_status_check'
  end

  def down
    remove_check_constraint :consents, name: 'consents_status_check'
    change_column_default :consents, :status, from: 'pending', to: 'received'
    add_check_constraint :consents,
                         "status IN ('#{CONSENT_STATUSES_WITHOUT_PENDING.join("','")}')",
                         name: 'consents_status_check'
  end
end
