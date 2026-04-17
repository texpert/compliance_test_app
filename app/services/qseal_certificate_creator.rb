# frozen_string_literal: true

require 'openssl'
require 'securerandom'

class QsealCertificateCreator
  # id-etsi-qct-eseal — declares certificate is a Qualified Electronic Seal (eIDAS Annex III)
  QCT_ESEAL_OID = '0.4.0.1862.1.2'
  # id-etsi-psd2-qcStatement — PSD2 roles container per ETSI TS 119 495
  PSD2_QC_STATEMENT_OID = '0.4.0.19495.2'
  # id-pe-qcStatements — X.509 extension OID
  QC_STATEMENTS_EXT_OID = '1.3.6.1.5.5.7.1.3'

  # Returns [Certificate, QsealCertificate] or raises on error
  def self.create!(provider:, ca_certificate:, name:, roles: QsealCertificate::PSP_ROLES.keys)
    new(provider: provider, ca_certificate: ca_certificate, name: name, roles: roles).create!
  end

  def initialize(provider:, ca_certificate:, name:, roles:)
    @provider = provider
    @ca_certificate = ca_certificate
    @name = name
    @roles = roles
  end

  def create!
    out_name = derive_out_name
    client_key = OpenSSL::PKey::RSA.new(2048)
    csr = build_csr(client_key, out_name)

    @parsed_ca_cert = OpenSSL::X509::Certificate.new(@ca_certificate.pem_content)
    ca_key = OpenSSL::PKey::RSA.new(@ca_certificate.private_key)

    signed_cert = sign_certificate(csr, @parsed_ca_cert, ca_key)

    ActiveRecord::Base.transaction do
      qseal = QsealCertificate.create!(
        provider: @provider,
        tsp_name: derive_tsp_name,
        qc_statement_data: @roles
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

  def derive_tsp_name
    cn = @parsed_ca_cert.subject.to_a.find { |name, _, _| name == 'CN' }&.at(1)
    o  = @parsed_ca_cert.subject.to_a.find { |name, _, _| name == 'O' }&.at(1)
    cn.presence || o.presence || @ca_certificate.name
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
    cert.add_extension(build_qc_statements_extension)
  end

  # Builds qcStatements per ETSI TS 119 495:
  #   - id-etsi-qct-eseal (0.4.0.1862.1.2): Qualified Electronic Seal declaration
  #   - id-etsi-psd2-qcStatement (0.4.0.19495.2): PSD2 roles with NCA info
  def build_qc_statements_extension
    eseal_statement = OpenSSL::ASN1::Sequence.new([
      OpenSSL::ASN1::ObjectId.new(QCT_ESEAL_OID)
    ])

    psd2_roles_seq = OpenSSL::ASN1::Sequence.new(
      @roles.map do |role|
        OpenSSL::ASN1::Sequence.new([
          OpenSSL::ASN1::ObjectId.new(QsealCertificate::PSP_ROLES.fetch(role)[:oid]),
          OpenSSL::ASN1::UTF8String.new(role)
        ])
      end
    )

    psd2_info = OpenSSL::ASN1::Sequence.new([
      psd2_roles_seq,
      OpenSSL::ASN1::UTF8String.new('SaltEdge Test NCA'),
      OpenSSL::ASN1::UTF8String.new('SALTEDGE-TEST')
    ])

    psd2_statement = OpenSSL::ASN1::Sequence.new([
      OpenSSL::ASN1::ObjectId.new(PSD2_QC_STATEMENT_OID),
      psd2_info
    ])

    qc_statements = OpenSSL::ASN1::Sequence.new([eseal_statement, psd2_statement])
    OpenSSL::X509::Extension.new(QC_STATEMENTS_EXT_OID, qc_statements.to_der, false)
  end
end
