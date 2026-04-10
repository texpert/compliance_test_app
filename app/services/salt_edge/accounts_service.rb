# frozen_string_literal: true

module SaltEdge
  # Fetches the account list for an authorised consent.
  #
  # Usage:
  #   SaltEdge::AccountsService.new.accounts(consent_id: "abc-123")
  #   # => [{ "resourceId" => "…", "iban" => "…", "currency" => "EUR", … }, …]
  class AccountsService
    def initialize(config: SaltEdge::Config.new, request_adapter: SaltEdge::RequestAdapter.new)
      @config = config
      @request_adapter = request_adapter
    end

    def accounts(consent_id:)
      response = @request_adapter.request(
        method: :get,
        path: '/v1/accounts',
        headers: { 'Consent-ID' => consent_id }
      )
      raise response.error if response.failure?

      response.data['accounts'] || []
    end
  end
end
