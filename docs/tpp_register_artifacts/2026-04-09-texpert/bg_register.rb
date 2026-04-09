require 'openssl'
require 'securerandom'
require 'jwt'
require 'json'
require 'rest-client'

####################################################
# Fill Config

YOUR_PEM_CERTIFICATE = File.read('texpert/texpert_client_signed_certifcate.crt')
YOUR_CERTIFICATES_PRIVATE_RSA_KEY = File.read('texpert/texpert_client_private.key')
COMPANY_NAME = "Texpert"
CONTACT_EMAIL = "branzeanu.aurel+tpp@gmail.com"
####################################################

class SignatureHelper
  REQUIRED_HEADERS    = %w(Digest Date X-Request-ID)
  CONDITIONAL_HEADERS = %w(Psu-ID Psu-Corporate-ID TPP-Redirect-URI)

  attr_reader :certificate, :private_key, :headers, :body

  def initialize(headers: {}, body: "", certificate: nil, private_key: nil)
    @certificate = certificate
    @private_key = private_key
    @body        = body
    @headers     = headers.merge(
      "Digest"       => "SHA-256=#{Digest::SHA256.base64digest(body)}",
      "Date"         => Time.now.httpdate,
      "X-Request-ID" => SecureRandom.uuid,
      "Content-Type" => "application/json",
      "TPP-Signature-Certificate" => Base64.strict_encode64(@certificate.to_s)
    )
  end

  def signed_headers
    @headers.merge("Signature" => signature)
  end

  def signature
    return @signature if @signature

    signature = Base64.strict_encode64(private_key.sign("RSA-SHA256", signing_string))
    @signature = [
      "Signature keyId=\"SN=#{certificate.serial},DN=#{certificate.issuer}\"",
      "algorithm=\"rsa-sha256\"",
      "headers=\"#{signible_headers.keys.join(" ").downcase}\"",
      "signature=\"#{signature}\""
    ].join(",")
  end

  def signible_headers
    return @signible_headers if @signible_headers

    supported_headers = (REQUIRED_HEADERS + CONDITIONAL_HEADERS)
    @signible_headers = headers.select { |header| supported_headers.include?(header)  }
  end

  def signing_string
    signible_headers.each_with_object("") do |(header, value), object|
      object << "#{header.downcase}: #{value}\n"
    end.strip!
  end
end

PRIORA_BASE_URL = 'https://priora.saltedge.com'
path = '/api/berlingroup/v1/tpp/register'
@payload = {
  certificate: {
    name: "Test Certificate",
    type: "qseal",
    pem: YOUR_PEM_CERTIFICATE
  },
  company: {
    name: COMPANY_NAME,
    email: CONTACT_EMAIL,
    address:  "Fake street 34",
    city: "Chisinau",
    zip_code: "2001",
    phone_number: "+373012345678"
  },
  representative: {
    name: "TPP Representative",
    email: CONTACT_EMAIL
  }
}
helper = SignatureHelper.new(
  headers:     { 'X-Request-ID' => SecureRandom.uuid },
  body:        @payload.to_json,
  certificate: OpenSSL::X509::Certificate.new(YOUR_PEM_CERTIFICATE),
  private_key: OpenSSL::PKey::RSA.new(YOUR_CERTIFICATES_PRIVATE_RSA_KEY)
)

@request_opts = {
  method:  'POST',
  url:     PRIORA_BASE_URL + path,
  headers: helper.signed_headers,
  payload: helper.body
}

begin
  response = RestClient::Request.execute(@request_opts)
rescue => e
  puts '-----ERROR-----'
  begin
    puts JSON.parse e.response
  rescue
    puts e.message
  end
  puts '-----ERROR-----\n'
end

puts '-----REQUEST OPTIONS-----'
puts @request_opts
puts '-----REQUEST OPTIONS-----\n'

if response
  puts '-----RESPONSE-----'
  puts JSON.parse response.body
  puts '-----RESPONSE-----\n'
end
