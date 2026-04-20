# frozen_string_literal: true

# == Schema Information
#
# Table name: accounts
#
#  id                :integer          not null, primary key
#  bban              :string
#  bic               :string
#  cash_account_type :string
#  currency          :string           not null
#  iban              :string
#  msisdn            :string
#  name              :string
#  owner_name        :string
#  product           :string
#  raw_data          :json             not null
#  status            :string
#  usage             :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  resource_id       :string           not null
#
# Indexes
#
#  index_accounts_on_resource_id  (resource_id) UNIQUE
#
FactoryBot.define do
  factory :account do
    sequence(:resource_id) { |n| "acc-#{n.to_s.rjust(3, '0')}" }
    iban { 'DE89370400440532013000' }
    currency { 'EUR' }
    name { 'Checking Account' }
    raw_data { {} }
  end
end
