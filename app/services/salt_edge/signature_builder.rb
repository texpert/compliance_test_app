# frozen_string_literal: true

require 'openssl'
require 'base64'

module SaltEdge
  # Builds cryptographic signatures for Salt Edge API requests.
  #
  # Implements RFC 3230 Digest header and custom HTTP Signature scheme:
  #   Digest: SHA-256=<base64(SHA-256(body))>
  #   Signature: keyId="<cert-fingerprint>",algorithm="rsa-sha256",headers="...",signature="<base64>"
  #   TPP-Signature-Certificate: <base64(DER-cert)>
  class SignatureBuilder
    attr_reader :config

    def initialize(config = SaltEdge::Config.new)
      @config = config
    end

    # Build all signing headers for a request.
    #
    # @param method [String] HTTP method (GET, POST, etc.)
    # @param path [String] Request path (e.g., '/v1/consents')
    # @param body [String, nil] Request body (nil or empty for GET)
    # @param request_id [String] Unique request ID
    # @param date [Time] Request date (typically now)
    #
    # @return [Hash] Headers hash with Digest, Signature, TPP-Signature-Certificate
    def build_headers(method:, path:, body: nil, request_id: nil, date: nil)
      request_id ||= SecureRandom.uuid
      date ||= Time.current
      body_str = body.is_a?(String) ? body : (body ? body.to_json : '')

      {
        'Digest'                    => build_digest(body_str),
        'Signature'                 => build_signature(method, path, request_id, date, body_str),
        'TPP-Signature-Certificate' => load_certificate_b64,
        'X-Request-ID'              => request_id,
        'Date'                      => date.httpdate
      }
    end

    private

    # Build the Digest header: SHA-256=<base64(SHA-256(body))>
    def build_digest(body)
      digest = Digest::SHA256.digest(body)
      encoded = Base64.strict_encode64(digest)
      "SHA-256=#{encoded}"
    end

    # Build the Signature header with RSA-SHA256.
    def build_signature(method, path, request_id, date, body_str)
      # Canonicalize the signing string per HTTP Signature spec
      digest_value = build_digest(body_str).sub('SHA-256=', '')
      request_target = "#{method.downcase} #{path}"
      signing_string = [
        "(request-target): #{request_target}",
        "date: #{date.httpdate}",
        "x-request-id: #{request_id}",
        "digest: SHA-256=#{digest_value}"
      ].join("\n")

      # Sign with RSA-SHA256
      signature_bytes = sign_with_private_key(signing_string)
      signature_b64 = Base64.strict_encode64(signature_bytes)

      # Build the Signature header
      cert_fingerprint = certificate_fingerprint
      'keyId="' + cert_fingerprint + '",' \
      'algorithm="rsa-sha256",' \
      'headers="(request-target) date x-request-id digest",' \
      'signature="' + signature_b64 + '"'
    end

    # Sign data with the QSEAL private key using RSA-SHA256.
    def sign_with_private_key(data)
      key = load_private_key
      key.sign(OpenSSL::Digest.new('SHA256'), data)
    end

    # Load the QSEAL certificate from disk and return as base64-encoded DER.
    def load_certificate_b64
      cert_pem = File.read(config.qseal_cert_path)
      cert = OpenSSL::X509::Certificate.new(cert_pem)
      Base64.strict_encode64(cert.to_der)
    end

    # Load the QSEAL private key from disk.
    def load_private_key
      key_pem = File.read(config.qseal_key_path)
      OpenSSL::PKey::RSA.new(key_pem, config.qseal_key_passphrase)
    end

    # Compute the SHA-256 fingerprint of the certificate (hex format).
    def certificate_fingerprint
      cert_pem = File.read(config.qseal_cert_path)
      cert = OpenSSL::X509::Certificate.new(cert_pem)
      digest = OpenSSL::Digest.new('SHA256')
      fingerprint = digest.digest(cert.to_der)
      fingerprint.unpack1('H*')
    end
  end
end
