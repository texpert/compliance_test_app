# frozen_string_literal: true

FactoryBot.define do
  factory :account do
    sequence(:resource_id) { |n| "acc-#{n.to_s.rjust(3, '0')}" }
    iban { 'DE89370400440532013000' }
    currency { 'EUR' }
    name { 'Checking Account' }
    raw_data { {} }
  end
end
