# frozen_string_literal: true

class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.string :transaction_id
      t.string :booking_status, null: false
      t.date :booking_date
      t.date :value_date
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.string :currency, null: false
      t.string :creditor_name
      t.string :creditor_iban
      t.string :debtor_name
      t.string :debtor_iban
      t.text :remittance_information_unstructured
      t.string :proprietary_bank_transaction_code
      t.json :raw_data, null: false, default: {}

      t.timestamps
    end

    add_index :transactions, %i[account_id transaction_id],
              unique: true,
              where: 'transaction_id IS NOT NULL',
              name: 'index_transactions_on_account_id_and_transaction_id'
  end
end
