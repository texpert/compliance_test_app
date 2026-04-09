# frozen_string_literal: true


RSpec.describe SaltEdge::SignatureBuilder do
  let(:config) do
    double(SaltEdge::Config,
           qseal_cert_path: Rails.root.join('spec/fixtures/test-cert.pem').to_s,
           qseal_key_path: Rails.root.join('spec/fixtures/test-key.pem').to_s,
           qseal_key_passphrase: 'test-passphrase')
  end

  subject(:builder) { described_class.new(config) }

  before do
    # Create minimal test fixtures (self-signed cert + key)
    generate_test_cert_and_key
  end

  def generate_test_cert_and_key
    fixtures_dir = Rails.root.join('spec/fixtures')
    FileUtils.mkdir_p(fixtures_dir)

    # Generate a test RSA key
    key = OpenSSL::PKey::RSA.new(2048)
    key_file = fixtures_dir.join('test-key.pem')
    File.write(key_file, OpenSSL::PKey::RSA.new(key).export(OpenSSL::Cipher.new('AES-256-CBC'), 'test-passphrase'))

    # Generate a self-signed certificate
    subject = OpenSSL::X509::Name.parse('/C=US/O=Test/CN=test.example.com')
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = subject
    cert.issuer = subject
    cert.public_key = key.public_key
    cert.not_before = Time.current
    cert.not_after = Time.current + 365 * 24 * 3600
    cert.sign(key, OpenSSL::Digest.new('SHA256'))

    cert_file = fixtures_dir.join('test-cert.pem')
    File.write(cert_file, cert.to_pem)
  end

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
      # SHA-256 of "test body" is specific
      expect(digest).to be_a(String)
      expect(digest.length).to be > 10
    end

    it 'computes Digest as empty string SHA-256 for GET requests without body' do
      headers = builder.build_headers(
        method: 'GET',
        path: '/v1/accounts'
      )

      digest = headers['Digest']
      # SHA-256 of empty string = 47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=
      expect(digest).to eq('SHA-256=47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=')
    end

    it 'generates a valid Signature header with keyId, algorithm, headers, signature' do
      headers = builder.build_headers(
        method: 'POST',
        path: '/v1/consents',
        body: '{"test":"payload"}',
        request_id: 'abc-123'
      )

      signature = headers['Signature']
      expect(signature).to include('keyId="')
      expect(signature).to include('algorithm="rsa-sha256"')
      expect(signature).to include('headers="(request-target) date x-request-id digest"')
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
      # Should be valid base64
      expect { Base64.strict_decode64(cert_b64) }.not_to raise_error
    end
  end

  describe '#build_digest' do
    it 'returns SHA-256=<base64> for a non-empty body' do
      digest = builder.send(:build_digest, 'hello world')
      expect(digest).to start_with('SHA-256=')
      # SHA-256 base64 should be ~43 chars (256 bits / 8 * 4/3)
      expect(digest.length).to be > 40
    end

    it 'returns SHA-256 of empty string for empty body' do
      digest = builder.send(:build_digest, '')
      expect(digest).to eq('SHA-256=47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=')
    end
  end

  describe '#certificate_fingerprint' do
    it 'returns a hex-formatted SHA-1 fingerprint' do
      fingerprint = builder.send(:certificate_fingerprint)
      expect(fingerprint).to be_a(String)
      # SHA-1 fingerprint should be 40 hex chars (160 bits / 4)
      expect(fingerprint).to match(/^[a-f0-9]{40}$/)
    end

    it 'returns consistent fingerprint on multiple calls' do
      fp1 = builder.send(:certificate_fingerprint)
      fp2 = builder.send(:certificate_fingerprint)
      expect(fp1).to eq(fp2)
    end
  end

  describe 'integration' do
    it 'produces deterministic signatures for the same input' do
      date = Time.parse('2026-04-10 12:00:00 UTC')
      body = '{"test":"payload"}'
      request_id = 'test-123'

      headers1 = builder.build_headers(
        method: 'POST',
        path: '/v1/consents',
        body: body,
        request_id: request_id,
        date: date
      )

      headers2 = builder.build_headers(
        method: 'POST',
        path: '/v1/consents',
        body: body,
        request_id: request_id,
        date: date
      )

      expect(headers1['Digest']).to eq(headers2['Digest'])
      expect(headers1['Signature']).to eq(headers2['Signature'])
      expect(headers1['Date']).to eq(headers2['Date'])
    end

    it 'produces different signatures for different request paths' do
      headers1 = builder.build_headers(
        method: 'POST',
        path: '/v1/consents'
      )

      headers2 = builder.build_headers(
        method: 'POST',
        path: '/v1/accounts'
      )

      expect(headers1['Signature']).not_to eq(headers2['Signature'])
    end
  end
end
