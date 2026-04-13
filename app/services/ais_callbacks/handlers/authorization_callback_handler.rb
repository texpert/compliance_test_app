# frozen_string_literal: true

module AisCallbacks
  module Handlers
    class AuthorizationCallbackHandler
      # The handler only performs consent status reconciliation.
      # Accounts and transactions fetching are deferred to manual operator actions.
      def initialize(consent_service: SaltEdge::ConsentService.new)
        @consent_service = consent_service
      end

      def call(consent:, callback_state:, code:, callback_params:, callback_request_headers:)
        if consent.upstream_consent_id.blank?
          return HandlerResult.error(http_status: :unprocessable_content, error_body: { 'error' => 'missing_upstream_consent_id' })
        end

        # Allow replay only when progressing out of partiallyAuthorised; reject all others.
        if Event.callback_replayed?(consent: consent, consent_id: consent.id, state: callback_state, code: code) &&
           consent.status_before_type_cast != 'partiallyAuthorised'
          return HandlerResult.error(http_status: :conflict, error_body: { 'error' => 'state_replay' })
        end

        unless consent.update(callback_received_at: Time.now.utc, callback_params: callback_params)
          return HandlerResult.error(http_status: :unprocessable_content, error_body: { 'error' => 'callback_persist_failed' })
        end

        # Note: incoming callback Event is recorded once by CallbackProcessor; handlers only record outgoing HTTP events.

        consent_status = @consent_service.consent_status(consent.upstream_consent_id)
        mapped_status = Consent.status_value(consent_status)

        Event.record(
          event_type: 'consent_status_check',
          provider: consent.provider,
          consent: consent,
          request_body: { consent_id: consent.upstream_consent_id },
          response_body: { consent_status: mapped_status }
        )

        unless consent.update(status: mapped_status)
          return HandlerResult.error(http_status: :unprocessable_content, error_body: { 'error' => 'consent_update_failed' })
        end

        if mapped_status != Consent::STATUS_VALID
          consent.update(callback_error: "consent_not_valid: #{mapped_status}")
          return HandlerResult.error(
            http_status: :forbidden,
            error_body: { 'error' => 'consent_not_valid', 'consent_status' => mapped_status }
          )
        end

        HandlerResult.ok(
          consent: consent,
          response_body: { 'consent_status' => mapped_status, 'note' => 'accounts_and_transactions_fetch_deferred' }
        )
      end
    end
  end
end
