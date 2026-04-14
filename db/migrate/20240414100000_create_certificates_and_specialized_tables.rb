class CreateCertificatesAndSpecializedTables < ActiveRecord::Migration[7.1]
  def change
    create_table :certificates do |t|
      t.string   :subject, null: false
      t.string   :issuer_dn
      t.string   :serial_number, null: false
      t.datetime :not_before
      t.datetime :not_after
      t.text     :pem_content
      t.text     :csr
      t.text     :private_key           # Encrypted
      t.text     :public_key_pem
      t.string   :public_key_hash
      t.string   :certifiable_type, null: false
      t.integer  :certifiable_id, null: false
      t.integer  :issuer_id
      t.string   :status, default: 'pending', null: false
      t.string   :revocation_reason
      t.datetime :revoked_at
      t.timestamps
    end

    create_table :ca_certificates do |t|
      t.boolean :is_root, default: false
      t.integer :path_length_constraint
    end

    create_table :qseal_certificates do |t|
      t.references :provider, null: false, foreign_key: true
      t.string :qc_statement_id, null: false
      t.string :tsp_name, null: false
      t.json  :custom_attributes, default: {}
    end

    add_foreign_key :certificates, :certificates, column: :issuer_id
    add_index :certificates, :public_key_hash
    add_index :certificates, :status
    add_index :certificates, [:certifiable_type, :certifiable_id]
  end
end
