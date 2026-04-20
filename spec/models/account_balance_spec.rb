# frozen_string_literal: true

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
