# frozen_string_literal: true

class RenameQcStatementIdToQcStatementData < ActiveRecord::Migration[8.1]
  def up
    rename_column :qseal_certificates, :qc_statement_id, :qc_statement_data
    change_column :qseal_certificates, :qc_statement_data, :json, null: false, default: []
  end

  def down
    change_column :qseal_certificates, :qc_statement_data, :string, null: false
    rename_column :qseal_certificates, :qc_statement_data, :qc_statement_id
  end
end
