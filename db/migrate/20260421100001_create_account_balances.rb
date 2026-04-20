# frozen_string_literal: true

class CreateAccountBalances < ActiveRecord::Migration[8.1]
  def change
    create_table :account_balances do |t|
      t.references :account, null: false, foreign_key: true
      t.string :balance_type, null: false
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.string :currency, null: false
      t.boolean :credit_limit_included, default: false, null: false
      t.date :reference_date
      t.datetime :last_change_date_time

      t.timestamps
    end

    add_index :account_balances, [:account_id, :balance_type], unique: true
  end
end
