# frozen_string_literal: true

require 'cgi'

module SaltEdge
  # Fetches a single page of transactions for a given account under an authorised consent.
  #
  # Two public entry points:
  #   transactions(...)       – backward-compatible single-page call, returns transactions hash only.
  #   transactions_page(...)  – single-page call that also returns next_href for external pagination.
  #
  # Pagination iteration (when needed) is driven by the caller (e.g. TransactionsFetchService),
  # which can persist each page before fetching the next — avoiding loading all pages into memory.
  class TransactionsService
    DEFAULT_DATE_RANGE_DAYS = 30

    def initialize(config: SaltEdge::Config.new, request_adapter: nil, certificate: nil)
      @config = config
      @request_adapter = request_adapter || build_adapter(certificate)
    end

    # Returns the transactions hash { 'booked' => [...], 'pending' => [...] } for a single page.
    def transactions(account_id:, consent_id:, date_from: nil, date_to: nil, booking_status: 'both')
      resolved_to   = date_to&.to_date   || Date.current
      resolved_from = date_from&.to_date || (resolved_to - DEFAULT_DATE_RANGE_DAYS)

      fetch_raw_page(
        path: transactions_path(account_id, resolved_from, resolved_to, booking_status),
        consent_id: consent_id
      )[:transactions]
    end

    # Returns { transactions: {...}, next_href: '...' | nil } for a single page.
    # Pass `path:` to fetch a subsequent page using the href from a previous result's next_href.
    # When `path:` is omitted the initial paginated URL is built from the other arguments.
    def transactions_page(account_id: nil, consent_id:, date_from: nil, date_to: nil,
                          booking_status: 'both', path: nil)
      resolved_path = path || begin
        resolved_to   = date_to&.to_date   || Date.current
        resolved_from = date_from&.to_date || (resolved_to - DEFAULT_DATE_RANGE_DAYS)
        "#{transactions_path(account_id, resolved_from, resolved_to, booking_status)}&paginated=1"
      end

      fetch_raw_page(path: resolved_path, consent_id: consent_id)
    end

    private

    def fetch_raw_page(path:, consent_id:)
      response = @request_adapter.request(method: :get, path: path, headers: { 'Consent-ID' => consent_id })
      raise response.error if response.failure?

      {
        transactions: response.data['transactions'] || {},
        next_href:    response.data.dig('_links', 'next', 'href')
      }
    end

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
