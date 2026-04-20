# frozen_string_literal: true

module SaltEdge
  # Fetches transactions from upstream and persists them locally.
  #
  # Non-paginated: fetches the full result in one request, upserts booked, replaces pending.
  # Paginated:     iterates pages via _links.next, persisting each page before fetching the next
  #                to keep memory usage bounded to a single page at a time.
  #
  # Usage:
  #   SaltEdge::TransactionsFetchService.new(certificate: cert)
  #     .fetch_and_persist(account: account, consent_id: "abc-123",
  #                        date_from: 90.days.ago.to_date, date_to: Date.current,
  #                        booking_status: 'both')
  #   # => [#<Transaction ...>, ...]
  class TransactionsFetchService
    def initialize(certificate:, config: SaltEdge::Config.new, request_adapter: nil)
      @transactions_service = SaltEdge::TransactionsService.new(
        config: config,
        certificate: certificate,
        request_adapter: request_adapter
      )
    end

    def fetch_and_persist(account:, consent_id:, date_from: nil, date_to: nil,
                          booking_status: 'both', paginated: false)
      if paginated
        persist_pages(account: account, consent_id: consent_id, date_from: date_from,
                      date_to: date_to, booking_status: booking_status)
      else
        data = @transactions_service.transactions(
          account_id: account.resource_id, consent_id: consent_id,
          date_from: date_from, date_to: date_to, booking_status: booking_status
        )
        upsert_booked(account, data['booked'] || []).size +
          replace_pending(account, data['pending'] || []).size
      end
    end

    private

    # Deletes pending transactions once upfront, then fetches and persists one page at a time.
    def persist_pages(account:, consent_id:, date_from:, date_to:, booking_status:)
      account.transactions.where(booking_status: Transaction::BOOKING_STATUS_PENDING).delete_all

      count = 0
      path  = nil

      loop do
        page = @transactions_service.transactions_page(
          account_id: account.resource_id,
          consent_id: consent_id,
          date_from:  date_from,
          date_to:    date_to,
          booking_status: booking_status,
          path: path
        )

        txs    = page[:transactions]
        count += upsert_booked(account, txs['booked'] || []).size
        count += persist_pending_batch(account, txs['pending'] || []).size

        break if page[:next_href].blank?
        path = page[:next_href]
      end

      count
    end

    def upsert_booked(account, booked_data)
      booked_data.map do |tx_data|
        tx_id = tx_data['transactionId']
        transaction = if tx_id.present?
          account.transactions.find_or_initialize_by(
            transaction_id: tx_id,
            booking_status: Transaction::BOOKING_STATUS_BOOKED
          )
        else
          account.transactions.build(booking_status: Transaction::BOOKING_STATUS_BOOKED)
        end
        assign_attributes(transaction, tx_data, Transaction::BOOKING_STATUS_BOOKED)
        transaction.save!
        transaction
      end
    end

    def replace_pending(account, pending_data)
      account.transactions.where(booking_status: Transaction::BOOKING_STATUS_PENDING).delete_all
      persist_pending_batch(account, pending_data)
    end

    def persist_pending_batch(account, pending_data)
      pending_data.map do |tx_data|
        transaction = account.transactions.build(booking_status: Transaction::BOOKING_STATUS_PENDING)
        assign_attributes(transaction, tx_data, Transaction::BOOKING_STATUS_PENDING)
        transaction.save!
        transaction
      end
    end

    def assign_attributes(transaction, data, booking_status)
      amount_data = data['transactionAmount'] || {}
      transaction.assign_attributes(
        booking_status: booking_status,
        booking_date: parse_date(data['bookingDate']),
        value_date: parse_date(data['valueDate']),
        amount: amount_data['amount'],
        currency: amount_data['currency'].presence || transaction.account.currency,
        creditor_name: data['creditorName'],
        creditor_iban: data.dig('creditorAccount', 'iban'),
        debtor_name: data['debtorName'],
        debtor_iban: data.dig('debtorAccount', 'iban'),
        remittance_information_unstructured: data['remittanceInformationUnstructured'],
        proprietary_bank_transaction_code: data['proprietaryBankTransactionCode'],
        raw_data: data
      )
    end

    def parse_date(value)
      Date.parse(value) if value.present?
    rescue ArgumentError, TypeError
      nil
    end
  end
end
