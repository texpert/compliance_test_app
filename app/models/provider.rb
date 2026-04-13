# frozen_string_literal: true

# == Schema Information
#
# Table name: providers
#
#  id         :integer          not null, primary key
#  code       :string           not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_providers_on_code  (code) UNIQUE
#
class Provider < ApplicationRecord
  has_many :consents, dependent: :destroy
  has_many :events, dependent: :nullify

  validates :name, presence: true
  validates :code, presence: true, uniqueness: true
end
