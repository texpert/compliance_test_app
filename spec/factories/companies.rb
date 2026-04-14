# frozen_string_literal: true

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
