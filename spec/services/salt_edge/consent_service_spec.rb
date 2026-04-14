# frozen_string_literal: true

RSpec.describe SaltEdge::ConsentService do
  let(:company) { create(:company) }
  let(:user) { create(:user) }
  let(:provider) { create(:provider, company: company, representative: user) }

  let(:consent_config) do
    instance_double(
      SaltEdge::Config,
      redirect_uri: 'https://example.ngrok.io/callback',
      psu_ip_address: '9.9.9.9'
    )
  end
  let(:adapter_config) { instance_double(SaltEdge::Config, api_base_url: 'https://priora.saltedge.com', http_timeout: 30) }
  let(:signer) { instance_double(SaltEdge::SignatureBuilder) }
  let(:request_adapter) { SaltEdge::RequestAdapter.new(config: adapter_config, signer: signer, client: HTTPX) }

  subject(:service) { described_class.new(config: consent_config, request_adapter: request_adapter) }

  describe '#create_consent' do
    let(:upstream_data) do
      {
        'consentId' => 'consent-123',
        'consentStatus' => 'received',
        '_links' => {
          'scaRedirect' => { 'href' => 'https://aspsp.example/sca' }
        }
      }
    end
    let(:signed_headers) do
      {
        'Signature' => 'sig',
        'Digest' => 'SHA-256=abc',
        'X-Request-ID' => 'request-1',
        'Date' => 'Fri, 10 Apr 2026 12:00:00 GMT',
        'TPP-Signature-Certificate' => 'cert'
      }
    end

    before do
      allow(signer).to receive(:build_headers).and_return(signed_headers)
    end

    it 'creates a consent through the HTTP adapter and maps the response' do
      stub_create_consent(consent_id: 'consent-123', consent_status: 'received', sca_url: 'https://aspsp.example/sca')

      result = service.create_consent(consent_id: 123, valid_until: Date.new(2026, 12, 31))

      expect(a_request(:post, 'https://priora.saltedge.com/v1/consents')).to have_been_made
      expect(
        a_request(:post, 'https://priora.saltedge.com/v1/consents').with(
          headers: {
            'TPP-Redirect-Preferred' => 'true',
            'TPP-Redirect-URI' => 'https://example.ngrok.io/callback?id=123',
            'PSU-IP-Address' => '9.9.9.9',
            'Signature' => 'sig'
          },
          body: '{"access":{"allPsd2":"allAccounts"},"recurringIndicator":true,"validUntil":"2026-12-31","frequencyPerDay":4,"combinedServiceIndicator":false}'
        )
      ).to have_been_made

      expect(result).to eq(
        'consent_id' => 'consent-123',
        'consent_status' => 'received',
        'sca_redirect_url' => 'https://aspsp.example/sca',
        'raw' => upstream_data
      )
      expect(signer).to have_received(:build_headers).with(
        method: 'post',
        path: '/v1/consents',
        body: '{"access":{"allPsd2":"allAccounts"},"recurringIndicator":true,"validUntil":"2026-12-31","frequencyPerDay":4,"combinedServiceIndicator":false}'
      )
    end

    it 'raises when upstream returns a non-2xx response' do
      stub_request(:post, 'https://priora.saltedge.com/v1/consents')
        .to_return(status: 400, body: '{"tppMessages":[{"text":"upstream failed"}]}')

      expect { service.create_consent(consent_id: 123) }.to raise_error(SaltEdge::RequestError, 'upstream failed')
    end
  end

  describe '#consent_status' do
    let(:signed_headers) do
      {
        'Signature' => 'sig',
        'Digest' => 'SHA-256=abc',
        'X-Request-ID' => 'request-1',
        'Date' => 'Fri, 10 Apr 2026 12:00:00 GMT',
        'TPP-Signature-Certificate' => 'cert'
      }
    end

    before do
      allow(signer).to receive(:build_headers).and_return(signed_headers)
    end

    it 'calls the status endpoint and returns consentStatus' do
      stub_consent_status('consent-123', 'valid')

      result = service.consent_status('consent-123')

      expect(a_request(:get, 'https://priora.saltedge.com/v1/consents/consent-123/status')).to have_been_made.once
      expect(result).to eq('valid')
    end
  end

  describe '#create_and_persist_consent' do
    let(:consent_record) { provider.consents.create!(upstream_consent_id: nil, status: Consent::STATUS_RECEIVED, callback_params: {}) }

    it 'calls create_consent, persists upstream ids and returns response' do
      upstream = {
        'consentId' => 'consent-xyz',
        'consentStatus' => 'partiallyAuthorised',
        '_links' => { 'scaRedirect' => { 'href' => 'https://aspsp.example/sca' } }
      }

      allow(service).to receive(:create_consent).and_return(
        'consent_id' => upstream['consentId'],
        'consent_status' => upstream['consentStatus'],
        'sca_redirect_url' => upstream.dig('_links', 'scaRedirect', 'href'),
        'raw' => upstream
      )

      resp = service.create_and_persist_consent(consent: consent_record)

      expect(resp['consent_id']).to eq('consent-xyz')
      expect(consent_record.reload.upstream_consent_id).to eq('consent-xyz')
      expect(consent_record.reload.status_before_type_cast).to eq('partiallyAuthorised')
    end

    it 'does not persist when upstream request fails' do
      allow(service).to receive(:create_consent).and_raise(SaltEdge::RequestError.new('upstream failed'))

      expect do
        service.create_and_persist_consent(consent: consent_record)
      end.to raise_error(SaltEdge::RequestError)

      expect(consent_record.reload.upstream_consent_id).to be_nil
    end

    it 'raises when saving the consent to DB fails and does not persist upstream id' do
      upstream = {
        'consentId' => 'consent-xyz',
        'consentStatus' => 'received',
        '_links' => { 'scaRedirect' => { 'href' => 'https://aspsp.example/sca' } }
      }

      allow(service).to receive(:create_consent).and_return(
        'consent_id' => upstream['consentId'],
        'consent_status' => upstream['consentStatus'],
        'sca_redirect_url' => upstream.dig('_links', 'scaRedirect', 'href'),
        'raw' => upstream
      )

      allow(consent_record).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError.new('save failed'))

      expect do
        service.create_and_persist_consent(consent: consent_record)
      end.to raise_error(ActiveRecord::ActiveRecordError)

      expect(consent_record.reload.upstream_consent_id).to be_nil
    end

    it 'maps unknown upstream statuses to received' do
      upstream = {
        'consentId' => 'consent-xyz',
        'consentStatus' => 'mystery',
        '_links' => { 'scaRedirect' => { 'href' => 'https://aspsp.example/sca' } }
      }

      allow(service).to receive(:create_consent).and_return(
        'consent_id' => upstream['consentId'],
        'consent_status' => upstream['consentStatus'],
        'sca_redirect_url' => upstream.dig('_links', 'scaRedirect', 'href'),
        'raw' => upstream
      )

      resp = service.create_and_persist_consent(consent: consent_record)

      expect(consent_record.reload.status_before_type_cast).to eq('received')
      expect(resp['consent_status']).to eq('mystery')
    end
  end
end
