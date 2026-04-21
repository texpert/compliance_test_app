# frozen_string_literal: true

module SaltEdge
  # Typed, validated configuration for Salt Edge API integration.
  #
  # Reads environment variables prefixed with SE_:
  #   SE_API_BASE_URL, SE_CALLBACK_BASE_URL,
  #   SE_API_PROVIDER_CODE, SE_PSU_IP_ADDRESS
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
      :psu_ip_address,
      api_provider_code: 'artea_sandbox',
      http_timeout_seconds: 30

    required :api_base_url,
             :callback_base_url

    coerce_types http_timeout_seconds: :integer

    def http_timeout
      http_timeout_seconds.to_i
    end

  end
end
