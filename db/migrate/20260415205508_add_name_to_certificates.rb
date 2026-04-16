class AddNameToCertificates < ActiveRecord::Migration[8.1]
  def change
    add_column :certificates, :name, :string
  end
end
