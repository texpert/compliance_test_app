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
class Account < ApplicationRecord
  has_many :account_balances, dependent: :destroy
  has_many :transactions, dependent: :destroy

  validates :resource_id, presence: true, uniqueness: true
  validates :currency, presence: true

  def self.ransackable_attributes(auth_object = nil)
    %w[id resource_id iban bban currency name status usage owner_name created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[account_balances]
  end
end
