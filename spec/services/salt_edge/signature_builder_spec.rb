# frozen_string_literal: true

RSpec.describe SaltEdge::SignatureBuilder do
  let(:company)  { create(:company) }
  let(:user)     { create(:user) }
  let(:provider) { create(:provider, company: company, representative: user) }

  let(:ca_cert) { CaRootCertificateCreator.create!(key_size: 1024).first }
  let(:certificate) do
    QsealCertificateCreator.create!(provider: provider, ca_certificate: ca_cert, name: 'Test QSeal').first
  end

  subject(:builder) { described_class.new(certificate: certificate) }

  describe '#build_headers' do
    it 'returns a hash with required signing headers' do
      headers = builder.build_headers(
        method: 'POST',
        path: '/v1/consents',
        body: '{"access":{"allPsd2":"allAccounts"}}',
        request_id: 'test-request-id',
        date: Time.parse('2026-04-10 12:00:00 UTC')
      )

      expect(headers).to be_a(Hash)
      expect(headers).to include(
        'Digest',
        'Signature',
        'TPP-Signature-Certificate',
        'X-Request-ID',
        'Date'
      )
    end

    it 'generates a valid Digest header with SHA-256 base64' do
      headers = builder.build_headers(
        method: 'POST',
        path: '/v1/consents',
        body: 'test body'
      )

      digest = headers['Digest']
      expect(digest).to match(/^SHA-256=/)
      expect(digest).to be_a(String)
      expect(digest.length).to be > 10
    end

    it 'computes Digest as empty string SHA-256 for GET requests without body' do
      headers = builder.build_headers(
        method: 'GET',
        path: '/v1/accounts'
      )

      expect(headers['Digest']).to eq('SHA-256=47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=')
    end

    it 'generates a valid Signature header with keyId, algorithm, headers, signature' do
      headers = builder.build_headers(
        method: 'POST',
        path: '/v1/consents',
        body: '{"test":"payload"}',
        request_id: 'abc-123'
      )

      signature = headers['Signature']
      expect(signature).to start_with('Signature keyId="SN=')
      expect(signature).to include(',DN=')
      expect(signature).to include('algorithm="rsa-sha256"')
      expect(signature).to include('headers="digest date x-request-id"')
      expect(signature).to include('signature="')
    end

    it 'includes X-Request-ID in headers' do
      headers = builder.build_headers(
        method: 'GET',
        path: '/v1/accounts',
        request_id: 'my-request-id'
      )

      expect(headers['X-Request-ID']).to eq('my-request-id')
    end

    it 'generates a unique X-Request-ID when not provided' do
      headers1 = builder.build_headers(method: 'GET', path: '/v1/accounts')
      headers2 = builder.build_headers(method: 'GET', path: '/v1/accounts')

      expect(headers1['X-Request-ID']).not_to eq(headers2['X-Request-ID'])
    end

    it 'includes Date header in HTTP date format' do
      date = Time.parse('2026-04-10 12:00:00 UTC')
      headers = builder.build_headers(
        method: 'GET',
        path: '/v1/accounts',
        date: date
      )

      expect(headers['Date']).to eq('Fri, 10 Apr 2026 12:00:00 GMT')
    end

    it 'includes TPP-Signature-Certificate as base64-encoded DER' do
      headers = builder.build_headers(
        method: 'POST',
        path: '/v1/consents',
        body: '{}'
      )

      cert_b64 = headers['TPP-Signature-Certificate']
      expect(cert_b64).to be_a(String)
      expect { Base64.strict_decode64(cert_b64) }.not_to raise_error
    end
  end

  describe '#build_digest' do
    it 'returns SHA-256=<base64> for a non-empty body' do
      digest = builder.send(:build_digest, 'hello world')
      expect(digest).to start_with('SHA-256=')
      expect(digest.length).to be > 40
    end

    it 'returns SHA-256 of empty string for empty body' do
      digest = builder.send(:build_digest, '')
      expect(digest).to eq('SHA-256=47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=')
    end
  end

  describe '#certificate_key_id' do
    it 'returns SN=<serial>,DN=<issuer> format' do
      key_id = builder.send(:certificate_key_id)
      expect(key_id).to match(/^SN=\d+,DN=/)
    end

    it 'returns consistent key_id on multiple calls' do
      expect(builder.send(:certificate_key_id)).to eq(builder.send(:certificate_key_id))
    end
  end

  describe 'integration' do
    it 'produces deterministic signatures for the same input' do
      date = Time.parse('2026-04-10 12:00:00 UTC')
      body = '{"test":"payload"}'
      request_id = 'test-123'

      headers1 = builder.build_headers(method: 'POST', path: '/v1/consents', body: body, request_id: request_id, date: date)
      headers2 = builder.build_headers(method: 'POST', path: '/v1/consents', body: body, request_id: request_id, date: date)

      expect(headers1['Digest']).to eq(headers2['Digest'])
      expect(headers1['Signature']).to eq(headers2['Signature'])
      expect(headers1['Date']).to eq(headers2['Date'])
    end

    it 'produces different signatures for different request bodies' do
      date = Time.parse('2026-04-10 12:00:00 UTC')
      rid = 'test-id'
      headers1 = builder.build_headers(method: 'POST', path: '/v1/consents', body: '{"a":1}', request_id: rid, date: date)
      headers2 = builder.build_headers(method: 'POST', path: '/v1/consents', body: '{"a":2}', request_id: rid, date: date)

      expect(headers1['Signature']).not_to eq(headers2['Signature'])
    end
  end
end
