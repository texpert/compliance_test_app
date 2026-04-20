# frozen_string_literal: true

ActiveAdmin.register AccountBalance do
  menu false
  actions :show

  show do
    attributes_table do
      row(:account) { |b| link_to "Account #{b.account.resource_id}", [:admin, b.account] }
      row :balance_type
      row :amount
      row :currency
      row :credit_limit_included
      row :reference_date
      row('Last Change') { |b| b.last_change_date_time&.strftime('%Y-%m-%d %H:%M UTC') || '—' }
      row('Updated') { |b| b.updated_at.strftime('%Y-%m-%d %H:%M UTC') }
    end
  end
end
