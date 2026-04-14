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
end
