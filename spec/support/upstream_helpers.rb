# frozen_string_literal: true

module UpstreamHelpers
  def stub_create_consent(consent_id: 'consent-123', consent_status: 'received', sca_url: 'https://aspsp.example/sca', provider_code: 'artea_sandbox')
    upstream = {
      'consentId' => consent_id,
      'consentStatus' => consent_status,
      '_links' => { 'scaRedirect' => { 'href' => sca_url } }
    }

    stub_request(:post, "https://priora.saltedge.com/#{provider_code}/api/berlingroup/v1/consents")
      .to_return(status: 201, body: upstream.to_json, headers: { 'Content-Type' => 'application/json' })

    upstream
  end

  def stub_consent_status(consent_id, statuses, provider_code: 'artea_sandbox')
    responses = Array(statuses).map do |s|
      { status: 200, body: { consentStatus: s }.to_json, headers: { 'Content-Type' => 'application/json' } }
    end

    stub_request(:get, "https://priora.saltedge.com/#{provider_code}/api/berlingroup/v1/consents/#{consent_id}/status")
      .to_return(*responses)
  end

  def stub_accounts(consent_id:, accounts: [], provider_code: 'artea_sandbox')
    body = { accounts: accounts }.to_json
    stub_request(:get, "https://priora.saltedge.com/#{provider_code}/api/berlingroup/v1/accounts")
      .with(headers: { 'Consent-ID' => consent_id })
      .to_return(status: 200, body: body, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_accounts_error(status: 403, body: { 'tppMessages' => [{ 'text' => 'CONSENT_INVALID' }] }, provider_code: 'artea_sandbox')
    stub_request(:get, "https://priora.saltedge.com/#{provider_code}/api/berlingroup/v1/accounts")
      .to_return(status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_transactions(account_id:, consent_id:, transactions: {}, provider_code: 'artea_sandbox')
    path_regex = %r{https://priora\.saltedge\.com/#{Regexp.escape(provider_code)}/api/berlingroup/v1/accounts/#{Regexp.escape(account_id)}/transactions.*}
    stub_request(:get, path_regex)
      .with(headers: { 'Consent-ID' => consent_id })
      .to_return(status: 200, body: { transactions: transactions }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_transactions_error(account_id:, status: 401, body: { 'tppMessages' => [{ 'text' => 'CONSENT_EXPIRED' }] }, provider_code: 'artea_sandbox')
    path_regex = %r{https://priora\.saltedge\.com/#{Regexp.escape(provider_code)}/api/berlingroup/v1/accounts/#{Regexp.escape(account_id)}/transactions.*}
    stub_request(:get, path_regex)
      .to_return(status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_timeout_for(method, url)
    stub_request(method, url).to_timeout
  end

  # Load a canned upstream fixture from spec/fixtures/upstream/<name>.json
  def load_upstream_fixture(name)
    path = Rails.root.join('spec', 'fixtures', 'upstream', "#{name}.json")
    JSON.parse(File.read(path))
  end

  def stub_accounts_from_fixture(consent_id:, fixture_name:)
    data = load_upstream_fixture(fixture_name)
    stub_accounts(consent_id: consent_id, accounts: data['accounts'])
  end

  def stub_transactions_from_fixture(account_id:, consent_id:, fixture_name:)
    data = load_upstream_fixture(fixture_name)
    stub_transactions(account_id: account_id, consent_id: consent_id, transactions: data['transactions'])
  end
end

RSpec.configure do |config|
  config.include UpstreamHelpers
end
