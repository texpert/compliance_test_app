# frozen_string_literal: true

RSpec.describe SaltEdge::RequestAdapter do
  let(:config) { instance_double(SaltEdge::Config, api_base_url: 'https://priora.saltedge.com', http_timeout: 30) }
  let(:signer) { instance_double(SaltEdge::SignatureBuilder) }
  let(:client) { instance_double('HTTPX::Session') }
  let(:timeout_client) { instance_double('HTTPX::Session') }

  subject(:adapter) { described_class.new(config: config, signer: signer, client: client) }

  describe '#request' do
    let(:signed_headers) do
      {
        'Signature' => 'sig',
        'Digest' => 'SHA-256=abc',
        'X-Request-ID' => 'request-1',
        'Date' => 'Fri, 10 Apr 2026 12:00:00 GMT',
        'TPP-Signature-Certificate' => 'cert'
      }
    end

    it 'returns a successful RequestResult with parsed data' do
      response = instance_double('HTTPX::Response', status: 201, body: '{"ok":true}')

      allow(signer).to receive(:build_headers).and_return(signed_headers)
      allow(client).to receive(:with).with(timeout: 30).and_return(timeout_client)
      allow(timeout_client).to receive(:post).and_return(response)

      result = adapter.request(
        method: :post,
        path: '/v1/consents',
        body: { foo: 'bar' },
        headers: { 'Content-Type' => 'application/json' }
      )

      expect(result).to be_a(SaltEdge::RequestResult)
      expect(result).to be_success
      expect(result.data).to eq('ok' => true)
      expect(signer).to have_received(:build_headers).with(method: 'post', path: '/v1/consents', body: '{"foo":"bar"}')
      expect(timeout_client).to have_received(:post).with(
        'https://priora.saltedge.com/v1/consents',
        hash_including(headers: hash_including('Content-Type' => 'application/json', 'Signature' => 'sig'))
      )
    end

    it 'uses explicit timeout when provided' do
      response = instance_double('HTTPX::Response', status: 200, body: '{}')

      allow(signer).to receive(:build_headers).and_return(signed_headers)
      allow(client).to receive(:with).with(timeout: 5).and_return(timeout_client)
      allow(timeout_client).to receive(:get).and_return(response)

      adapter.request(method: :get, path: '/v1/consents/1/status', timeout: 5)

      expect(client).to have_received(:with).with(timeout: 5)
    end

    it 'returns failed RequestResult for non-2xx responses with normalized RequestError' do
      body = '{"tppMessages":[{"code":"FORMAT_ERROR","text":"Missing header"}]}'
      response = instance_double('HTTPX::Response', status: 400, body: body)

      allow(signer).to receive(:build_headers).and_return(signed_headers)
      allow(client).to receive(:with).and_return(timeout_client)
      allow(timeout_client).to receive(:get).and_return(response)

      result = adapter.request(method: :get, path: '/v1/accounts')

      expect(result).to be_failure
      expect(result.error).to be_a(SaltEdge::RequestError)
      expect(result.error.status).to eq(400)
      expect(result.error.code).to eq('FORMAT_ERROR')
      expect(result.error.message).to eq('Missing header')
    end

    it 'returns failed RequestResult on transport errors' do
      allow(signer).to receive(:build_headers).and_return(signed_headers)
      allow(client).to receive(:with).and_return(timeout_client)
      allow(timeout_client).to receive(:get).and_raise(StandardError, 'connection dropped')

      result = adapter.request(method: :get, path: '/v1/accounts')

      expect(result).to be_failure
      expect(result.error).to be_a(SaltEdge::RequestError)
      expect(result.error.message).to include('connection dropped')
    end

    it 'returns raw_body hash when upstream body is not JSON' do
      response = instance_double('HTTPX::Response', status: 200, body: 'OK')

      allow(signer).to receive(:build_headers).and_return(signed_headers)
      allow(client).to receive(:with).and_return(timeout_client)
      allow(timeout_client).to receive(:get).and_return(response)

      result = adapter.request(method: :get, path: '/v1/accounts')

      expect(result).to be_success
      expect(result.data).to eq('raw_body' => 'OK')
    end
  end
end
