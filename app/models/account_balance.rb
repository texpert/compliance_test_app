# frozen_string_literal: true

# == Schema Information
#
# Table name: account_balances
#
#  id                    :integer          not null, primary key
#  amount                :decimal(15, 2)   not null
#  balance_type          :string           not null
#  credit_limit_included :boolean          default(FALSE), not null
#  currency              :string           not null
#  last_change_date_time :datetime
#  reference_date        :date
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer          not null
#
# Indexes
#
#  index_account_balances_on_account_id                   (account_id)
#  index_account_balances_on_account_id_and_balance_type  (account_id,balance_type) UNIQUE
#
# Foreign Keys
#
#  account_id  (account_id => accounts.id)
#
class AccountBalance < ApplicationRecord
  belongs_to :account

  validates :balance_type, presence: true, uniqueness: { scope: :account_id }
  validates :amount, presence: true, numericality: true
  validates :currency, presence: true

  def self.ransackable_attributes(auth_object = nil)
    %w[id balance_type amount currency credit_limit_included reference_date account_id]
  end
end
