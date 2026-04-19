# frozen_string_literal: true

class AisTransactionsController < ApplicationController
  include AisConsentLookup
  skip_before_action :verify_browser, raise: false

  # GET /ais/consents/:id/accounts/:account_id/transactions
  # account_id can be omitted (consent-level route) to auto-derive from first account
  def index
    cert = @consent.provider.latest_qseal_cert
    account_id = params[:account_id]
    if account_id.blank?
      accounts = SaltEdge::AccountsService.new(certificate: cert)
                                          .accounts(consent_id: @consent.upstream_consent_id)
      account_id = accounts.first&.fetch('resourceId', nil)
      return render(json: { error: 'no_account_available' }, status: :unprocessable_content) unless account_id
    end

    transactions = SaltEdge::TransactionsService.new(certificate: cert)
                                                .transactions(account_id: account_id, consent_id: @consent.upstream_consent_id)

    Event.record(
      event_type: 'transactions_fetch',
      provider: @consent.provider,
      consent: @consent,
      request_body: { consent_id: @consent.upstream_consent_id, account_id: account_id },
      response_body: { transactions: transactions }
    )

    render json: { transactions: transactions }
  rescue SaltEdge::RequestError => e
    Event.record(
      event_type: 'transactions_fetch',
      provider: @consent.provider,
      consent: @consent,
      request_body: { consent_id: @consent.upstream_consent_id, account_id: params[:account_id] },
      response_body: { error: 'upstream_error', message: e.message }
    )
    render json: { error: 'upstream_error', message: e.message }, status: :bad_gateway
  end
end
