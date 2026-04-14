# frozen_string_literal: true

# == Schema Information
#
# Table name: companies
#
#  id           :integer          not null, primary key
#  address      :string           not null
#  city         :string           not null
#  country_code :string           not null
#  email        :string           not null
#  name         :string           not null
#  phone_number :string           not null
#  zip_code     :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class Company < ApplicationRecord
  has_many :company_users
  has_many :users, through: :company_users
  has_many :providers

  validates :name, :email, :address, :phone_number, :zip_code, :city, :country_code, presence: true
  validate :country_code_is_iso_alpha2

  private

  def country_code_is_iso_alpha2
    return if country_code.blank?
    unless ISO3166::Country[country_code]
      errors.add(:country_code, 'is not a valid ISO 3166-1 alpha-2 country code')
    end
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[id name email address phone_number zip_code city country_code created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[company_users users providers]
  end
end
