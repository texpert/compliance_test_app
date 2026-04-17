# frozen_string_literal: true

# == Schema Information
#
# Table name: qseal_certificates
#
#  id                :integer          not null, primary key
#  custom_attributes :json
#  qc_statement_data :json             not null
#  tsp_name          :string           not null
#  provider_id       :integer          not null
#
# Indexes
#
#  index_qseal_certificates_on_provider_id  (provider_id)
#
# Foreign Keys
#
#  provider_id  (provider_id => providers.id)
#
class QsealCertificate < ApplicationRecord
  # PSD2 role definitions per ETSI TS 119 495.
  # Each key is the role code; :oid is the ETSI OID; :label is the full regulatory name.
  PSP_ROLES = {
    'PSP_AS' => { oid: '0.4.0.19495.1.1', label: 'Account Servicing Payment Service Provider (banks/ASPSPs)' },
    'PSP_PI' => { oid: '0.4.0.19495.1.2', label: 'Payment Initiation Service Provider (PISP)' },
    'PSP_AI' => { oid: '0.4.0.19495.1.3', label: 'Account Information Service Provider (AISP)' },
    'PSP_IC' => { oid: '0.4.0.19495.1.4', label: 'Card-based Payment Instruments Issuer (CBPII)' }
  }.freeze

  belongs_to :provider
  has_one :certificate_record, as: :certifiable, class_name: 'Certificate', dependent: :destroy

  validates :tsp_name, presence: true
  validates :qc_statement_data, presence: true
  validate :qc_statement_data_contains_valid_roles

  private

  def qc_statement_data_contains_valid_roles
    return unless qc_statement_data.is_a?(Array)

    invalid = qc_statement_data - PSP_ROLES.keys
    errors.add(:qc_statement_data, "contains invalid roles: #{invalid.join(', ')}") if invalid.any?
  end
end
