# frozen_string_literal: true

RSpec.describe CaRootCertificateValidator do
  let(:cert_pem) { CaRootCertificateCreator.create!.first.pem_content }

  it 'validates a proper CA Root certificate' do
    expect(described_class.valid?(cert_pem)).to be true
  end

  it 'returns false for a non-CA certificate' do
    # Generate a non-CA cert
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = OpenSSL::X509::Name.parse('/C=RO/O=SaltEdge/CN=User Cert')
    cert.issuer = cert.subject
    cert.public_key = key.public_key
    cert.not_before = Time.now
    cert.not_after = Time.now + 365 * 24 * 60 * 60
    cert.sign(key, OpenSSL::Digest::SHA256.new)
    expect(described_class.valid?(cert.to_pem)).to be false
  end
end
