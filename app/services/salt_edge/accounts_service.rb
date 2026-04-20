# frozen_string_literal: true

module SaltEdge
  # Fetches the account list for an authorised consent.
  #
  # Usage:
  #   SaltEdge::AccountsService.new(certificate: cert).accounts(consent_id: "abc-123")
  #   # => [{ "resourceId" => "…", "iban" => "…", "currency" => "EUR", … }, …]
  class AccountsService
    def initialize(config: SaltEdge::Config.new, request_adapter: nil, certificate: nil)
      @config = config
      @request_adapter = request_adapter || build_adapter(certificate)
    end

    def accounts(consent_id:)
      response = @request_adapter.request(
        method: :get,
        path: "/#{@config.api_provider_code}/api/berlingroup/v1/accounts",
        headers: { 'Consent-ID' => consent_id }
      )
      raise response.error if response.failure?

      response.data['accounts'] || []
    end

    private

    def build_adapter(certificate)
      SaltEdge::RequestAdapter.new(signer: SaltEdge::SignatureBuilder.new(certificate: certificate))
    end
  end
end
