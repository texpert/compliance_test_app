# frozen_string_literal: true

require 'json'
require 'uri'

module SaltEdge
  # Thin Salt Edge adapter over HttpxClient transport.
  class RequestAdapter
    def initialize(config: SaltEdge::Config.new, signer: nil, client: HttpxClient.session)
      @config = config
      @signer = signer
      @client = client
    end

    def request(method:, path:, body: nil, headers: {}, signed: true, timeout: nil)
      if signed && @signer.nil?
        return SaltEdge::RequestResult.new(
          status: nil,
          error: SaltEdge::RequestError.new('No signing certificate available')
        )
      end

      method_name = method.to_s.downcase
      body_json = json_body(body)
      signed_headers = signed ? @signer.build_headers(method: method_name, path: path, body: body_json) : {}
      merged_headers = signed_headers.merge!(headers)

      response = @client
                 .with(timeout: timeout_options(timeout || @config.http_timeout))
                 .public_send(method_name, build_url(path), **request_options(body_json, merged_headers))

      if response.is_a?(HTTPX::ErrorResponse)
        return SaltEdge::RequestResult.new(
          status: nil,
          request_headers: merged_headers,
          error: SaltEdge::RequestError.new("Salt Edge request failed: #{response.error.message}")
        )
      end

      resp_headers = headers_to_hash(response.headers)

      if response.status.between?(200, 299)
        return SaltEdge::RequestResult.new(
          status: response.status,
          request_headers: merged_headers,
          response_headers: resp_headers,
          data: parse_json_body(response.body.to_s)
        )
      end

      SaltEdge::RequestResult.new(
        status: response.status,
        request_headers: merged_headers,
        response_headers: resp_headers,
        error: build_error(response)
      )
    rescue StandardError => e
      SaltEdge::RequestResult.new(status: nil, error: SaltEdge::RequestError.new("Salt Edge request failed: #{e.message}"))
    end

    private

    def timeout_options(seconds)
      { operation_timeout: seconds }
    end

    def request_options(body_json, headers)
      return { headers: headers } if body_json.empty?

      { body: body_json, headers: { 'Content-Type' => 'application/json' }.merge!(headers) }
    end

    def build_url(path)
      base = @config.api_base_url.end_with?('/') ? @config.api_base_url : "#{@config.api_base_url}/"
      URI.join(base, path.sub(%r{^/}, '')).to_s
    end

    def json_body(body)
      return '' if body.nil?
      return body if body.is_a?(String)

      body.to_json
    end

    def parse_json_body(raw)
      return {} if raw.nil? || raw.strip.empty?

      JSON.parse(raw)
    rescue JSON::ParserError
      { 'raw_body' => raw }
    end

    def headers_to_hash(headers)
      headers.each_with_object({}) { |(k, v), h| h[k] = v }
    rescue StandardError
      {}
    end

    def build_error(response)
      raw = response.body.to_s
      parsed = parse_json_body(raw)

      code = parsed.dig('tppMessages', 0, 'code') || parsed['code']
      message = parsed.dig('tppMessages', 0, 'text') || parsed['message'] || "HTTP #{response.status}"

      SaltEdge::RequestError.new(message, status: response.status, code: code, upstream_body: raw)
    end
  end
end
