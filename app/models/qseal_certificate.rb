# == Schema Information
#
# Table name: qseal_certificates
#
#  id                :integer          not null, primary key
#  custom_attributes :json
#  tsp_name          :string           not null
#  provider_id       :integer          not null
#  qc_statement_id   :string           not null
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
  belongs_to :provider
  has_one :certificate_record, as: :certifiable, class_name: 'Certificate', dependent: :destroy
end
