# frozen_string_literal: true

ActiveAdmin.register Account do
  actions :index, :show

  config.sort_order = 'updated_at_desc'

  action_item :fetch_transactions, only: :show do
    eligible = Consent.where(status: [Consent::STATUS_VALID, Consent::STATUS_ACCEPTED]).exists?
    link_to 'Fetch Transactions', new_fetch_transactions_admin_account_path(resource) if eligible
  end

  member_action :new_fetch_transactions, method: :get do
    @account = resource
    @eligible_consents = Consent.where(status: [Consent::STATUS_VALID, Consent::STATUS_ACCEPTED])
                                .includes(:provider)
                                .order(created_at: :desc)
    render 'admin/accounts/new_fetch_transactions'
  end

  member_action :fetch_transactions, method: :post do
    account = resource
    consent = Consent.find_by(id: params[:consent_id])
    unless consent
      redirect_to admin_account_path(account), alert: 'Consent not found.'
      next
    end

    provider = consent.provider
    cert = provider.latest_qseal_cert
    unless cert
      redirect_to admin_account_path(account), alert: 'No issued QSeal certificate found.'
      next
    end

    if consent.status_accepted?
      consent_service = SaltEdge::ConsentService.new(certificate: cert)
      current_status = consent_service.consent_status(consent.upstream_consent_id)
      if current_status != consent.status_before_type_cast
        consent.update!(status: Consent.status_value(current_status))
      end
      unless consent.status_valid?
        redirect_to admin_account_path(account),
                    alert: "Consent #{consent.id} status is '#{consent.status_before_type_cast}' — please authorise it first."
        next
      end
    end

    date_from     = params[:date_from].present? ? Date.parse(params[:date_from]) : 90.days.ago.to_date
    date_to       = params[:date_to].present? ? Date.parse(params[:date_to]) : Date.current
    booking_status = params[:booking_status].presence || 'both'
    paginated      = params[:paginated] == '1'

    service = SaltEdge::TransactionsFetchService.new(certificate: cert)
    count   = service.fetch_and_persist(
      account: account,
      consent_id: consent.upstream_consent_id,
      date_from: date_from,
      date_to: date_to,
      booking_status: booking_status,
      paginated: paginated
    )

    redirect_to admin_account_path(account),
                notice: "Fetched #{count} transaction(s) successfully."
  rescue => e
    redirect_to admin_account_path(account), alert: "Failed to fetch transactions: #{e.message}"
  end

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

    panel 'Transactions' do
      recent = resource.transactions.order(booking_date: :desc, created_at: :desc).limit(20)
      if recent.any?
        div style: 'margin-bottom:0.5em;' do
          link_to 'View all transactions →',
                  admin_transactions_path(q: { account_id_eq: resource.id }),
                  style: 'font-size:0.9em;'
        end
        table_for recent do
          column(:id) { |t| link_to t.id, [:admin, t] }
          column :booking_status
          column :booking_date
          column :amount
          column :currency
          column :creditor_name
          column :debtor_name
          column('Remittance') { |t| truncate(t.remittance_information_unstructured, length: 50) }
        end
      else
        div class: 'blank_slate_container' do
          span 'No transactions fetched yet.', class: 'blank_slate'
        end
      end
    end
  end
end
