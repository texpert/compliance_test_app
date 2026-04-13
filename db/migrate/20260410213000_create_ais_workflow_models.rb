# frozen_string_literal: true

class CreateAisWorkflowModels < ActiveRecord::Migration[8.1]
  CONSENT_STATUSES = %w[
    accepted
    received
    valid
    partiallyAuthorised
    rejected
    revokedByPsu
    expired
    terminatedByTpp
  ].freeze

  def change
    create_table :providers do |t|
      t.string :name, null: false
      t.string :code, null: false

      t.timestamps
    end
    add_index :providers, :code, unique: true

    create_table :consents do |t|
      t.references :provider, null: false, foreign_key: true
      t.string :upstream_consent_id, null: true
      t.string :status, null: false, default: 'received'
      t.datetime :callback_received_at
      t.text :callback_error
      t.json :callback_params, null: false, default: {}

      t.timestamps
    end

    add_index :consents, %i[provider_id upstream_consent_id], unique: true, name: 'index_consents_on_provider_upstream'
    add_check_constraint :consents,
                         "status IN ('#{CONSENT_STATUSES.join("','")}')",
                         name: 'consents_status_check'

    create_table :events do |t|
      t.references :provider, foreign_key: true
      t.references :consent, foreign_key: true
      t.string :event_type, null: false
      t.json :request_headers, null: false, default: {}
      t.json :request_body, null: false, default: {}
      t.json :response_headers, null: false, default: {}
      t.json :response_body, null: false, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :events, :event_type
    add_index :events, :occurred_at
  end
end
