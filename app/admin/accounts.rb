# frozen_string_literal: true

ActiveAdmin.register Account do
  actions :index, :show

  config.sort_order = 'updated_at_desc'

  index do
    id_column
    column :resource_id
    column :iban
    column :currency
    column :name
    column :status
    column :usage
    column('Updated') { |a| a.updated_at.strftime('%Y-%m-%d %H:%M UTC') }
    actions
  end

  filter :resource_id
  filter :iban
  filter :currency
  filter :name
  filter :status

  show do
    attributes_table do
      row :resource_id
      row :iban
      row :bban
      row :bic
      row :msisdn
      row :currency
      row :name
      row :product
      row :cash_account_type
      row :status
      row :usage
      row :owner_name
      row('Updated') { |a| a.updated_at.strftime('%Y-%m-%d %H:%M UTC') }
    end

    panel 'Balances' do
      if resource.account_balances.any?
        table_for resource.account_balances.order(:balance_type) do
          column(:balance_type) { |b| link_to b.balance_type, [:admin, b] }
          column :amount
          column :currency
          column :credit_limit_included
          column :reference_date
          column('Last Change') { |b| b.last_change_date_time&.strftime('%Y-%m-%d %H:%M UTC') || '—' }
        end
      else
        div class: 'blank_slate_container' do
          span 'No balances fetched yet.', class: 'blank_slate'
        end
      end
    end
  end
end
