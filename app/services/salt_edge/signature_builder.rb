# frozen_string_literal: true

require 'openssl'
require 'base64'

module SaltEdge
  # Builds cryptographic signatures for Salt Edge API requests.
  #
  # Implements RFC 3230 Digest header and HTTP Signature scheme per Salt Edge spec:
  #   Digest: SHA-256=<base64(SHA-256(body))>
  #   Signature: Signature keyId="SN=<serial>,DN=<issuer>",algorithm="rsa-sha256",
  #              headers="digest date x-request-id",signature="<base64>"
  #   TPP-Signature-Certificate: <base64(DER-cert)>
  #
  # Reads the QSeal certificate PEM and private key from the given Certificate
  # AR record (private_key is stored encrypted via ActiveRecord::Encryption and
  # returned decrypted on read).
  class SignatureBuilder
    def initialize(certificate:)
      @certificate = certificate
    end

    # Build all signing headers for a request.
    #
    # @param method [String] HTTP method (GET, POST, etc.)
    # @param path [String] Request path (e.g., '/v1/consents')
    # @param body [String, nil] Request body (nil or empty for GET)
    # @param request_id [String] Unique request ID
    # @param date [Time] Request date (typically now)
    # @param additional_headers [Hash] Extra request headers to include in the signature
    #
    # @return [Hash] Headers hash with Digest, Signature, TPP-Signature-Certificate
    def build_headers(method:, path:, body: nil, request_id: nil, date: nil, additional_headers: {})
      request_id ||= SecureRandom.uuid
      date ||= Time.current
      body_str = body.is_a?(String) ? body : (body ? body.to_json : '')

      {
        'Digest'                    => build_digest(body_str),
        'Signature'                 => build_signature(request_id, date, body_str, additional_headers),
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
    # Signs digest, date, x-request-id, plus any additional_headers per Salt Edge BerlinGroup spec.
    def build_signature(request_id, date, body_str, additional_headers = {})
      extra_pairs = additional_headers.map { |k, v| [k.downcase, v.to_s] }

      signing_string = [
        "digest: #{build_digest(body_str)}",
        "date: #{date.httpdate}",
        "x-request-id: #{request_id}",
        *extra_pairs.map { |k, v| "#{k}: #{v}" }
      ].join("\n")

      header_names = (['digest', 'date', 'x-request-id'] + extra_pairs.map(&:first)).join(' ')
      signature_b64 = Base64.strict_encode64(sign_with_private_key(signing_string))

      'Signature keyId="' + certificate_key_id + '",' \
      'algorithm="rsa-sha256",' \
      "headers=\"#{header_names}\"," \
      'signature="' + signature_b64 + '"'
    end

    def sign_with_private_key(data)
      load_private_key.sign(OpenSSL::Digest.new('SHA256'), data)
    end

    def load_certificate_b64
      cert = OpenSSL::X509::Certificate.new(@certificate.pem_content)
      Base64.strict_encode64(cert.to_der)
    end

    def load_private_key
      OpenSSL::PKey::RSA.new(@certificate.private_key)
    end

    def certificate_key_id
      cert = OpenSSL::X509::Certificate.new(@certificate.pem_content)
      "SN=#{cert.serial},DN=#{cert.issuer}"
    end
  end
end
