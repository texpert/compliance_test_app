# frozen_string_literal: true

require 'openssl'
require 'securerandom'

class QsealCertificateCreator
  # Returns [Certificate, QsealCertificate] or raises on error
  def self.create!(provider:, ca_certificate:, name:)
    new(provider: provider, ca_certificate: ca_certificate, name: name).create!
  end

  def initialize(provider:, ca_certificate:, name:)
    @provider = provider
    @ca_certificate = ca_certificate
    @name = name
  end

  def create!
    out_name = derive_out_name
    client_key = OpenSSL::PKey::RSA.new(2048)
    csr = build_csr(client_key, out_name)

    ca_cert = OpenSSL::X509::Certificate.new(@ca_certificate.pem_content)
    ca_key = OpenSSL::PKey::RSA.new(@ca_certificate.private_key)

    signed_cert = sign_certificate(csr, ca_cert, ca_key)

    ActiveRecord::Base.transaction do
      qseal = QsealCertificate.create!(
        provider: @provider,
        tsp_name: @provider.company.official_name.presence || @provider.company.name,
        qc_statement_id: 'PSP_AI PSP_PI PSP_CI'
      )

      certificate = Certificate.create!(
        certifiable: qseal,
        name: @name,
        pem_content: signed_cert.to_pem,
        private_key: client_key.to_pem,
        csr: csr.to_pem,
        public_key_pem: signed_cert.public_key.to_pem,
        issuer: @ca_certificate,
        status: 'issued'
      )

      [certificate, qseal]
    end
  end

  private

  def derive_out_name
    @provider.company.name.tr(' ', '_').tr('-', '_').downcase
  end

  def build_csr(key, out_name)
    request = OpenSSL::X509::Request.new
    request.version = 0
    request.subject = OpenSSL::X509::Name.new([
      ['CN', "#{out_name} TEST TPP"],
      ['O', "TEST-TPP-#{out_name}"],
      ['C', 'RO'],
      ['ST', 'Fake street'],
      ['2.5.4.97', "TEST-TPP-#{out_name}", OpenSSL::ASN1::UTF8STRING]
    ])
    request.public_key = key.public_key
    request.sign(key, OpenSSL::Digest::SHA256.new)
    request
  end

  def sign_certificate(csr, ca_cert, ca_key)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = OpenSSL::BN.rand(128)
    cert.subject = csr.subject
    cert.issuer = ca_cert.subject
    cert.public_key = csr.public_key
    cert.not_before = Time.now.utc
    cert.not_after = Time.now.utc + (360 * 24 * 60 * 60)

    add_extensions(cert, ca_cert)

    cert.sign(ca_key, OpenSSL::Digest::SHA256.new)
    cert
  end

  def add_extensions(cert, ca_cert)
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = ca_cert

    cert.add_extension(ef.create_extension('basicConstraints', 'CA:TRUE', false))
    cert.add_extension(ef.create_extension('subjectKeyIdentifier', 'hash', false))
    cert.add_extension(ef.create_extension('keyUsage', 'digitalSignature,keyEncipherment', true))
    cert.add_extension(ef.create_extension('extendedKeyUsage', 'clientAuth,serverAuth', false))

    # id-pe-qcStatements (1.3.6.1.5.5.7.1.3) — PSP role statements per ETSI EN 319 412-5
    qc_seq = OpenSSL::ASN1::Sequence.new([
      OpenSSL::ASN1::Sequence.new([
        OpenSSL::ASN1::UTF8String.new('PSP_AI PSP_PI PSP_CI')
      ])
    ])
    cert.add_extension(OpenSSL::X509::Extension.new('1.3.6.1.5.5.7.1.3', qc_seq.to_der, false))
  end
end
