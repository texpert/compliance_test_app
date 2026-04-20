# frozen_string_literal: true

# == Schema Information
#
# Table name: transactions
#
#  id                                  :integer          not null, primary key
#  amount                              :decimal(15, 2)   not null
#  booking_date                        :date
#  booking_status                      :string           not null
#  creditor_iban                       :string
#  creditor_name                       :string
#  currency                            :string           not null
#  debtor_iban                         :string
#  debtor_name                         :string
#  proprietary_bank_transaction_code   :string
#  raw_data                            :json             not null
#  remittance_information_unstructured :text
#  value_date                          :date
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  account_id                          :integer          not null
#  transaction_id                      :string
#
# Indexes
#
#  index_transactions_on_account_id                     (account_id)
#  index_transactions_on_account_id_and_transaction_id  (account_id,transaction_id) UNIQUE WHERE transaction_id IS NOT NULL
#
# Foreign Keys
#
#  account_id  (account_id => accounts.id)
#
FactoryBot.define do
  factory :transaction do
    association :account
    sequence(:transaction_id) { |n| "tx-#{n.to_s.rjust(3, '0')}" }
    booking_status { Transaction::BOOKING_STATUS_BOOKED }
    booking_date { Date.current }
    value_date { Date.current }
    amount { '100.00' }
    currency { 'EUR' }
    raw_data { {} }

    trait :pending do
      booking_status { Transaction::BOOKING_STATUS_PENDING }
      transaction_id { nil }
    end
  end
end
