# frozen_string_literal: true

module SaltEdge
  # Typed, validated configuration for Salt Edge API integration.
  #
  # Reads environment variables prefixed with SE_:
  #   SE_API_BASE_URL, SE_CALLBACK_BASE_URL, SE_REDIRECT_URI,
  #   SE_CLIENT_ID, SE_CLIENT_SECRET, SE_PSU_IP_ADDRESS
  #
  # Usage:
  #   cfg = SaltEdge::Config.new
  #   cfg.api_base_url     # => "https://priora.saltedge.com"
  #   cfg.http_timeout     # => 30
  class Config < Anyway::Config
    config_name :se

    attr_config \
      :api_base_url,
      :callback_base_url,
      :redirect_uri,
      :client_id,
      :client_secret,
      :psu_ip_address,
      http_timeout_seconds: 30

    required :api_base_url,
             :callback_base_url,
             :redirect_uri

    coerce_types http_timeout_seconds: :integer

    def http_timeout
      http_timeout_seconds.to_i
    end

    def credentials?
      client_id.present? && client_secret.present?
    end
  end
end
