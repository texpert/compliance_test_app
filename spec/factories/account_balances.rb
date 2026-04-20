# frozen_string_literal: true

FactoryBot.define do
  factory :account_balance do
    association :account
    balance_type { 'closingBooked' }
    amount { '1000.00' }
    currency { 'EUR' }
    credit_limit_included { false }
  end
end
