# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SaltEdge::Config do
  # Full set of env values used across examples.
  # Optional keys are explicitly set to nil to isolate tests from any .env file loaded in test env.
  let(:valid_env) do
    {
      "SE_API_BASE_URL"         => "https://priora.saltedge.com",
      "SE_QSEAL_CERT_PATH"      => "/secrets/qseal/client.crt",
      "SE_QSEAL_KEY_PATH"       => "/secrets/qseal/client.key",
      "SE_CALLBACK_BASE_URL"    => "https://example.ngrok.io",
      "SE_REDIRECT_URI"         => "https://example.ngrok.io/callback",
      "SE_CLIENT_ID"            => nil,
      "SE_CLIENT_SECRET"        => nil,
      "SE_QSEAL_KEY_PASSPHRASE" => nil,
      "SE_PSU_IP_ADDRESS"       => nil,
      "SE_HTTP_TIMEOUT_SECONDS" => nil
    }
  end

  # Build a config instance with env vars set to the given hash
  def build_config(env_overrides = {})
    with_env(valid_env.merge(env_overrides)) { described_class.new }
  end

  def with_env(vars)
    original = vars.keys.each_with_object({}) { |k, h| h[k] = ENV[k] }
    vars.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    original.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  describe 'required attributes' do
    %w[
      SE_API_BASE_URL
      SE_QSEAL_CERT_PATH
      SE_QSEAL_KEY_PATH
      SE_CALLBACK_BASE_URL
      SE_REDIRECT_URI
    ].each do |var|
      it "raises when #{var} is missing" do
        expect { build_config(var => nil) }.to raise_error(Anyway::Config::ValidationError, /#{var.sub("SE_", "").downcase}/)
      end
    end
  end

  describe 'attribute defaults' do
    subject(:config) { build_config }

    it 'reads api_base_url from SE_API_BASE_URL' do
      expect(config.api_base_url).to eq('https://priora.saltedge.com')
    end

    it 'reads qseal_cert_path from SE_QSEAL_CERT_PATH' do
      expect(config.qseal_cert_path).to eq('/secrets/qseal/client.crt')
    end

    it 'reads qseal_key_path from SE_QSEAL_KEY_PATH' do
      expect(config.qseal_key_path).to eq('/secrets/qseal/client.key')
    end

    it 'reads callback_base_url from SE_CALLBACK_BASE_URL' do
      expect(config.callback_base_url).to eq('https://example.ngrok.io')
    end

    it 'reads redirect_uri from SE_REDIRECT_URI' do
      expect(config.redirect_uri).to eq('https://example.ngrok.io/callback')
    end

    it 'defaults http_timeout_seconds to 30 when SE_HTTP_TIMEOUT_SECONDS is unset' do
      expect(config.http_timeout_seconds).to eq(30)
    end

    it 'defaults http_timeout to 30' do
      expect(config.http_timeout).to eq(30)
    end

    it 'defaults client_id to nil' do
      expect(config.client_id).to be_nil
    end

    it 'defaults client_secret to nil' do
      expect(config.client_secret).to be_nil
    end

    it 'defaults qseal_key_passphrase to nil' do
      expect(config.qseal_key_passphrase).to be_nil
    end

    it 'defaults psu_ip_address to nil' do
      expect(config.psu_ip_address).to be_nil
    end
  end

  describe 'optional attributes' do
    it 'reads client_id from SE_CLIENT_ID when set' do
      config = build_config('SE_CLIENT_ID' => 'my-client-id')
      expect(config.client_id).to eq('my-client-id')
    end

    it 'reads client_secret from SE_CLIENT_SECRET when set' do
      config = build_config('SE_CLIENT_SECRET' => 'test-client-secret')
      expect(config.client_secret).to eq('test-client-secret')
    end

    it 'reads qseal_key_passphrase from SE_QSEAL_KEY_PASSPHRASE when set' do
      config = build_config('SE_QSEAL_KEY_PASSPHRASE' => 'test-passphrase-placeholder')
      expect(config.qseal_key_passphrase).to eq('test-passphrase-placeholder')
    end

    it 'reads psu_ip_address from SE_PSU_IP_ADDRESS when set' do
      config = build_config('SE_PSU_IP_ADDRESS' => '1.2.3.4')
      expect(config.psu_ip_address).to eq('1.2.3.4')
    end

    it 'reads and coerces http_timeout_seconds from SE_HTTP_TIMEOUT_SECONDS' do
      config = build_config('SE_HTTP_TIMEOUT_SECONDS' => '60')
      expect(config.http_timeout_seconds).to eq(60)
      expect(config.http_timeout).to eq(60)
    end
  end

  describe "#signing_key?" do
    it "returns true when qseal_key_path is present" do
      expect(build_config.signing_key?).to be true
    end

    it "cannot be instantiated with a blank qseal_key_path (required attr)" do
      expect { build_config("SE_QSEAL_KEY_PATH" => "") }
        .to raise_error(Anyway::Config::ValidationError, /qseal_key_path/)
    end
  end

  describe '#credentials?' do
    it 'returns false when client_id and client_secret are absent' do
      expect(build_config.credentials?).to be false
    end

    it 'returns false when only client_id is set' do
      expect(build_config('SE_CLIENT_ID' => 'id').credentials?).to be false
    end

    it 'returns false when only client_secret is set' do
      expect(build_config('SE_CLIENT_SECRET' => 'test-secret').credentials?).to be false
    end

    it 'returns true when both client_id and client_secret are set' do
      config = build_config('SE_CLIENT_ID' => 'test-id', 'SE_CLIENT_SECRET' => 'test-secret')
      expect(config.credentials?).to be true
    end
  end
end
