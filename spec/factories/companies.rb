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
FactoryBot.define do
  factory :company do
    name { 'Test Company' }
    email { 'test@company.com' }
    address { '123 Main St' }
    phone_number { '+1234567890' }
    zip_code { '12345' }
    city { 'Testville' }
    country_code { 'US' }
  end
end
