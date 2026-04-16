# frozen_string_literal: true

require 'openssl'
require 'securerandom'

class CaRootCertificateCreator
  # Returns [Certificate, CaCertificate] or raises on error
  def self.create!(subject: '/C=RO/ST=Fake street/O=SaltEdgeCA/CN=SaltEdge CA Authority',
                   key_size: 2048,
                   validity_years: 5,
                   name: 'SaltEdge CA Root')
    root_key = OpenSSL::PKey::RSA.new(key_size)
    root_ca = OpenSSL::X509::Certificate.new
    root_ca.version = 2
    root_ca.serial = SecureRandom.random_number(100_000_000)
    root_ca.subject = OpenSSL::X509::Name.parse(subject)
    root_ca.issuer = root_ca.subject
    root_ca.public_key = root_key.public_key
    root_ca.not_before = Time.now
    root_ca.not_after = Time.now + (validity_years * 365 * 24 * 60 * 60)

    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = root_ca
    ef.issuer_certificate = root_ca
    root_ca.add_extension(ef.create_extension('basicConstraints', 'CA:TRUE', true))
    root_ca.add_extension(ef.create_extension('keyUsage', 'keyCertSign, cRLSign', true))
    root_ca.add_extension(ef.create_extension('subjectKeyIdentifier', 'hash', false))
    root_ca.add_extension(ef.create_extension('authorityKeyIdentifier', 'keyid:always', false))

    root_ca.sign(root_key, OpenSSL::Digest::SHA256.new)

    ca = CaCertificate.create!(is_root: true)
    cert = Certificate.new(
      certifiable: ca,
      pem_content: root_ca.to_pem,
      private_key: root_key.to_pem,
      subject: root_ca.subject.to_s,
      issuer_dn: root_ca.issuer.to_s,
      serial_number: root_ca.serial.to_s,
      not_before: root_ca.not_before,
      not_after: root_ca.not_after,
      status: 'issued',
      name: name
    )
    cert.save!
    [cert, ca]
  end
end
