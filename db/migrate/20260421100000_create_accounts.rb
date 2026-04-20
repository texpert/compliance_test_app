# frozen_string_literal: true

class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :resource_id, null: false
      t.string :iban
      t.string :bban
      t.string :bic
      t.string :msisdn
      t.string :currency, null: false
      t.string :name
      t.string :product
      t.string :cash_account_type
      t.string :status
      t.string :usage
      t.string :owner_name
      t.json :raw_data, null: false, default: {}

      t.timestamps
    end

    add_index :accounts, :resource_id, unique: true
  end
end
