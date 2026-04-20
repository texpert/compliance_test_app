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
RSpec.describe Transaction, type: :model do
  describe 'validations' do
    it 'is valid with required attributes' do
      transaction = build(:transaction)
      expect(transaction).to be_valid
    end

    it 'requires booking_status' do
      tx = build(:transaction, booking_status: nil)
      expect(tx).not_to be_valid
      expect(tx.errors[:booking_status]).to be_present
    end

    it 'requires amount' do
      tx = build(:transaction, amount: nil)
      expect(tx).not_to be_valid
      expect(tx.errors[:amount]).to be_present
    end

    it 'requires currency' do
      tx = build(:transaction, currency: nil)
      expect(tx).not_to be_valid
      expect(tx.errors[:currency]).to be_present
    end

    it 'rejects invalid booking_status' do
      tx = build(:transaction, booking_status: 'unknown')
      expect(tx).not_to be_valid
      expect(tx.errors[:booking_status]).to be_present
    end

    it 'accepts booked status' do
      expect(build(:transaction, booking_status: 'booked')).to be_valid
    end

    it 'accepts pending status' do
      expect(build(:transaction, :pending)).to be_valid
    end
  end

  describe '.ransackable_attributes' do
    it 'includes expected filterable fields' do
      expect(described_class.ransackable_attributes).to include(
        'booking_status', 'booking_date', 'amount', 'currency', 'account_id'
      )
    end
  end

  describe 'BOOKING_STATUSES' do
    it 'contains booked and pending' do
      expect(Transaction::BOOKING_STATUSES).to contain_exactly('booked', 'pending')
    end
  end
end
