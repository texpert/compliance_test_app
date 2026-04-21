# frozen_string_literal: true

RSpec.describe SaltEdge::Config do
  # Full set of env values used across examples.
  # Optional keys are explicitly set to nil to isolate tests from any .env file loaded in test env.
  let(:valid_env) do
    {
      "SE_API_BASE_URL"         => "https://priora.saltedge.com",
      "SE_CALLBACK_BASE_URL"    => "https://example.ngrok.io",
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
      SE_CALLBACK_BASE_URL
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

    it 'reads callback_base_url from SE_CALLBACK_BASE_URL' do
      expect(config.callback_base_url).to eq('https://example.ngrok.io')
    end

    it 'defaults http_timeout_seconds to 30 when SE_HTTP_TIMEOUT_SECONDS is unset' do
      expect(config.http_timeout_seconds).to eq(30)
    end

    it 'defaults http_timeout to 30' do
      expect(config.http_timeout).to eq(30)
    end

    it 'defaults psu_ip_address to nil' do
      expect(config.psu_ip_address).to be_nil
    end
  end

  describe 'optional attributes' do
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
end
