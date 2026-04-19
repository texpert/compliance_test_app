# frozen_string_literal: true

class AisAccountsController < ApplicationController
  include AisConsentLookup
  skip_before_action :verify_browser, raise: false

  # GET /ais/consents/:id/accounts
  def index
    accounts = SaltEdge::AccountsService.new(certificate: @consent.provider.latest_qseal_cert)
                                        .accounts(consent_id: @consent.upstream_consent_id)

    Event.record(
      event_type: 'accounts_fetch',
      provider: @consent.provider,
      consent: @consent,
      request_body: { consent_id: @consent.upstream_consent_id },
      response_body: { accounts: accounts }
    )

    render json: { accounts: accounts }
  rescue SaltEdge::RequestError => e
    Event.record(
      event_type: 'accounts_fetch',
      provider: @consent.provider,
      consent: @consent,
      request_body: { consent_id: @consent.upstream_consent_id },
      response_body: { error: 'upstream_error', message: e.message }
    )
    render json: { error: 'upstream_error', message: e.message }, status: :bad_gateway
  end
end
