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
class Transaction < ApplicationRecord
  BOOKING_STATUS_BOOKED = 'booked'
  BOOKING_STATUS_PENDING = 'pending'
  BOOKING_STATUSES = [BOOKING_STATUS_BOOKED, BOOKING_STATUS_PENDING].freeze

  belongs_to :account

  validates :booking_status, presence: true, inclusion: { in: BOOKING_STATUSES }
  validates :amount, presence: true
  validates :currency, presence: true

  def self.ransackable_attributes(auth_object = nil)
    %w[id account_id booking_status booking_date value_date amount currency
       creditor_name creditor_iban debtor_name debtor_iban
       remittance_information_unstructured created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[account]
  end
end
