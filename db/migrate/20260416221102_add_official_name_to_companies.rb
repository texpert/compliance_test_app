class AddOfficialNameToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :official_name, :string
  end
end
