# frozen_string_literal: true

RSpec.describe Account, type: :model do
  describe 'validations' do
    it 'is valid with required attributes' do
      account = build(:account)
      expect(account).to be_valid
    end

    it 'requires resource_id' do
      account = build(:account, resource_id: nil)
      expect(account).not_to be_valid
      expect(account.errors[:resource_id]).to be_present
    end

    it 'requires currency' do
      account = build(:account, currency: nil)
      expect(account).not_to be_valid
      expect(account.errors[:currency]).to be_present
    end

    it 'enforces unique resource_id' do
      create(:account, resource_id: 'acc-unique')
      duplicate = build(:account, resource_id: 'acc-unique')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:resource_id]).to include('has already been taken')
    end
  end

  describe 'associations' do
    it 'has many account_balances' do
      account = create(:account)
      balance = create(:account_balance, account: account)
      expect(account.account_balances).to include(balance)
    end

    it 'destroys account_balances on destroy' do
      account = create(:account)
      create(:account_balance, account: account)
      expect { account.destroy }.to change(AccountBalance, :count).by(-1)
    end
  end
end
