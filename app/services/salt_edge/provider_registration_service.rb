# frozen_string_literal: true

module SaltEdge
  # Submits the TPP registration request to the Salt Edge Priora endpoint.
  #
  # Builds the registration payload from the provider's company data and
  # nominated representative, signs it via RequestAdapter/SignatureBuilder,
  # records an Event of type 'tpp_registration_request', and stamps
  # provider.registration_request_sent_at on success.
  class ProviderRegistrationService
    TPP_REGISTER_PATH = '/api/berlingroup/v1/tpp/register'

    def initialize(request_adapter: nil)
      @adapter = request_adapter
    end

    # @param provider [Provider]
    # @param representative [User]
    # @param certificate [Certificate, nil] issued QSeal cert; defaults to provider's latest
    # @return [SaltEdge::RequestResult]
    def register(provider:, representative:, certificate: nil)
      cert_record = certificate || provider.latest_qseal_cert
      return missing_cert_result unless cert_record

      adapter  = @adapter || build_adapter(cert_record)
      payload  = build_payload(cert_record, provider.company, representative)
      result   = adapter.request(method: :post, path: TPP_REGISTER_PATH, body: payload)

      record_event(provider: provider, payload: payload, result: result)
      provider.update!(registration_request_sent_at: Time.now.utc) if result.success?

      result
    end

    private

    def build_adapter(cert)
      SaltEdge::RequestAdapter.new(signer: SaltEdge::SignatureBuilder.new(certificate: cert))
    end

    def build_payload(cert_record, company, representative)
      {
        certificate: {
          name: cert_record.name,
          type: 'qseal',
          pem: cert_record.pem_content
        },
        company: {
          name: company.name,
          email: company.email,
          address: company.address,
          city: company.city,
          zip_code: company.zip_code,
          phone_number: company.phone_number
        },
        representative: {
          name: representative.name,
          email: representative.email
        }
      }
    end

    def record_event(provider:, payload:, result:)
      response_body = result.success? ? result.data : { 'error' => result.error.message, 'status' => result.status }
      Event.record(
        event_type: 'tpp_registration_request',
        provider: provider,
        request_headers: result.request_headers,
        request_body: payload,
        response_headers: result.response_headers,
        response_body: response_body
      )
    end

    def missing_cert_result
      SaltEdge::RequestResult.new(
        status: nil,
        error: SaltEdge::RequestError.new('No issued QSeal certificate found for provider')
      )
    end
  end
end
