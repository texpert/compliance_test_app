# frozen_string_literal: true

require 'cgi'

module SaltEdge
  # Fetches the transaction list for a given account under an authorised consent.
  #
  # Usage:
  #   SaltEdge::TransactionsService.new.transactions(
  #     account_id: "acc-001",
  #     consent_id: "abc-123",
  #     date_from:  Date.new(2026, 1, 1),
  #     date_to:    Date.new(2026, 3, 31)
  #   )
  #   # => { "booked" => […], "pending" => […] }
  class TransactionsService
    DEFAULT_DATE_RANGE_DAYS = 30

    def initialize(config: SaltEdge::Config.new, request_adapter: nil, certificate: nil)
      @config = config
      @request_adapter = request_adapter || build_adapter(certificate)
    end

    def transactions(account_id:, consent_id:, date_from: nil, date_to: nil, booking_status: 'both')
      resolved_to   = date_to&.to_date   || Date.current
      resolved_from = date_from&.to_date || (resolved_to - DEFAULT_DATE_RANGE_DAYS)

      response = @request_adapter.request(
        method: :get,
        path: transactions_path(account_id, resolved_from, resolved_to, booking_status),
        headers: { 'Consent-ID' => consent_id }
      )
      raise response.error if response.failure?

      response.data['transactions'] || {}
    end

    private

    def build_adapter(certificate)
      signer = SaltEdge::SignatureBuilder.new(certificate: certificate)
      SaltEdge::RequestAdapter.new(signer: signer)
    end

    def transactions_path(account_id, date_from, date_to, booking_status)
      "/#{@config.api_provider_code}/api/berlingroup/v1/accounts/#{CGI.escape(account_id.to_s)}/transactions" \
        "?bookingStatus=#{CGI.escape(booking_status)}" \
        "&dateFrom=#{date_from.iso8601}" \
        "&dateTo=#{date_to.iso8601}"
    end
  end
end
