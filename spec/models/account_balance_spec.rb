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
RSpec.describe AccountBalance, type: :model do
  describe 'validations' do
    it 'is valid with required attributes' do
      balance = build(:account_balance)
      expect(balance).to be_valid
    end

    it 'requires balance_type' do
      balance = build(:account_balance, balance_type: nil)
      expect(balance).not_to be_valid
      expect(balance.errors[:balance_type]).to be_present
    end

    it 'requires amount' do
      balance = build(:account_balance, amount: nil)
      expect(balance).not_to be_valid
      expect(balance.errors[:amount]).to be_present
    end

    it 'requires currency' do
      balance = build(:account_balance, currency: nil)
      expect(balance).not_to be_valid
      expect(balance.errors[:currency]).to be_present
    end

    it 'enforces unique balance_type per account' do
      account = create(:account)
      create(:account_balance, account: account, balance_type: 'closingBooked')
      duplicate = build(:account_balance, account: account, balance_type: 'closingBooked')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:balance_type]).to include('has already been taken')
    end

    it 'allows same balance_type on different accounts' do
      create(:account_balance, balance_type: 'closingBooked')
      another = build(:account_balance, balance_type: 'closingBooked')
      expect(another).to be_valid
    end
  end
end
