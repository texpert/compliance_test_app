# frozen_string_literal: true

ActiveAdmin.register Transaction do
  menu priority: 4, label: 'Transactions'
  actions :index, :show

  config.sort_order = 'booking_date_desc'

  filter :account_id, as: :select,
         collection: -> { Account.order(:resource_id).map { |a| [a.resource_id, a.id] } },
         label: 'Account'
  filter :booking_status, as: :select, collection: Transaction::BOOKING_STATUSES
  filter :booking_date_gteq, label: 'Booking date from', as: :date_picker
  filter :booking_date_lteq, label: 'Booking date to', as: :date_picker

  index do
    id_column
    column(:account) { |t| link_to t.account.resource_id, [:admin, t.account] }
    column :booking_status
    column :booking_date
    column :amount
    column :currency
    column :creditor_name
    column :debtor_name
    column('Remittance') { |t| truncate(t.remittance_information_unstructured, length: 60) }
    actions
  end

  show do
    attributes_table do
      row(:account) { |t| link_to t.account.resource_id, [:admin, t.account] }
      row :transaction_id
      row :booking_status
      row :booking_date
      row :value_date
      row :amount
      row :currency
      row :creditor_name
      row :creditor_iban
      row :debtor_name
      row :debtor_iban
      row :remittance_information_unstructured
      row :proprietary_bank_transaction_code
      row('Created') { |t| t.created_at.strftime('%Y-%m-%d %H:%M UTC') }
      row('Updated') { |t| t.updated_at.strftime('%Y-%m-%d %H:%M UTC') }
    end

    panel 'Raw Data' do
      pre style: 'white-space: pre-wrap; word-break: break-all; font-size: 0.85em;' do
        JSON.pretty_generate(resource.raw_data)
      end
    end
  end
end
