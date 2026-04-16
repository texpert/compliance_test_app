# frozen_string_literal: true

require 'openssl'

class CaRootCertificateValidator
  # Returns true if valid, else false. Optionally raises if raise_on_error is true.
  def self.valid?(certificate_pem, raise_on_error: false)
    cert = OpenSSL::X509::Certificate.new(certificate_pem)
    is_self_signed = cert.issuer.to_s == cert.subject.to_s
    is_ca = cert.extensions.any? { |ext| ext.oid == 'basicConstraints' && ext.value.include?('CA:TRUE') }
    begin
      signature_valid = cert.verify(cert.public_key)
    rescue OpenSSL::X509::CertificateError => e
      raise if raise_on_error
      signature_valid = false
    end
    valid = is_self_signed && is_ca && signature_valid
    raise 'Certificate is not a valid CA Root' if raise_on_error && !valid
    valid
  end
end
