# frozen_string_literal: true

# == Schema Information
#
# Table name: providers
#
#  id                :integer          not null, primary key
#  code              :string           not null
#  name              :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  company_id        :integer          not null
#  representative_id :integer          not null
#
# Indexes
#
#  index_providers_on_code               (code) UNIQUE
#  index_providers_on_company_id         (company_id)
#  index_providers_on_representative_id  (representative_id)
#
# Foreign Keys
#
#  company_id         (company_id => companies.id)
#  representative_id  (representative_id => users.id)
#

class Provider < ApplicationRecord
  belongs_to :company
  belongs_to :representative, class_name: 'User'
  has_many :consents, dependent: :destroy
  has_many :events, dependent: :nullify
  has_many :qseal_certificates
  # Allows accessing base certificates directly: providers.certificates
  has_many :certificates, through: :qseal_certificates, source: :certificate_record

  validates :name, presence: true
  validates :code, presence: true, uniqueness: true
  validates :company, presence: true
  validates :representative, presence: true
end
