# frozen_string_literal: true

module SaltEdge
  # Fetches accounts (and optionally balances) from upstream and upserts them locally.
  #
  # Usage:
  #   SaltEdge::AccountsFetchService.new(certificate: cert)
  #     .fetch_and_persist(consent_id: "abc-123", with_balance: true)
  #   # => [#<Account ...>, ...]
  class AccountsFetchService
    def initialize(certificate:, config: SaltEdge::Config.new, request_adapter: nil)
      @accounts_service = SaltEdge::AccountsService.new(
        config: config,
        certificate: certificate,
        request_adapter: request_adapter
      )
    end

    def fetch_and_persist(consent_id:, with_balance: false)
      upstream_accounts = @accounts_service.accounts(consent_id: consent_id, with_balance: with_balance)

      upstream_accounts.map do |data|
        account = Account.find_or_initialize_by(resource_id: data['resourceId'])
        account.assign_attributes(
          iban: data['iban'],
          bban: data['bban'],
          bic: data['bic'],
          msisdn: data['msisdn'],
          currency: data['currency'],
          name: data['name'],
          product: data['product'],
          cash_account_type: data['cashAccountType'],
          status: data['status'],
          usage: data['usage'],
          owner_name: data['ownerName'],
          raw_data: data
        )
        account.save!

        upsert_balances(account, data['balances']) if with_balance && data['balances'].present?

        account
      end
    end

    private

    def upsert_balances(account, balances)
      balances.each do |bal|
        amount_data = bal['balanceAmount'] || {}
        balance = account.account_balances.find_or_initialize_by(balance_type: bal['balanceType'])
        balance.assign_attributes(
          amount: amount_data['amount'],
          currency: amount_data['currency'].presence || account.currency,
          credit_limit_included: bal['creditLimitIncluded'] || false,
          reference_date: parse_date(bal['referenceDate']),
          last_change_date_time: parse_datetime(bal['lastChangeDateTime'])
        )
        balance.save!
      end
    end

    def parse_date(value)
      Date.parse(value) if value.present?
    rescue ArgumentError, TypeError
      nil
    end

    def parse_datetime(value)
      Time.parse(value) if value.present?
    rescue ArgumentError, TypeError
      nil
    end
  end
end
