class CreateCompaniesAndUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :address, null: false
      t.string :phone_number, null: false
      t.string :zip_code, null: false
      t.string :city, null: false
      t.string :country_code, null: false # ISO2
      t.timestamps
    end

    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.timestamps
    end

    create_table :companies_users, id: false do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
    end
    add_index :companies_users, [:company_id, :user_id], unique: true

    change_table :providers do |t|
      t.references :company, null: false, foreign_key: true
      t.references :representative, null: false, foreign_key: { to_table: :users }
    end
  end
end
