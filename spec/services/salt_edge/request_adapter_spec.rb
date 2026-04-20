# frozen_string_literal: true

RSpec.describe SaltEdge::RequestAdapter do
  let(:config) { instance_double(SaltEdge::Config, api_base_url: 'https://priora.saltedge.com', http_timeout: 30) }
  let(:signer) { instance_double(SaltEdge::SignatureBuilder) }
  let(:client) { HTTPX }

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

    before do
      allow(signer).to receive(:build_headers).and_return(signed_headers)
    end

    it 'returns a successful RequestResult with parsed data' do
      stub_request(:post, 'https://priora.saltedge.com/v1/consents')
        .with(
          headers: {
            'Content-Type' => 'application/json',
            'Signature' => 'sig'
          },
          body: '{"foo":"bar"}'
        )
        .to_return(status: 201, body: '{"ok":true}', headers: { 'Content-Type' => 'application/json' })

      result = adapter.request(
        method: :post,
        path: '/v1/consents',
        body: { foo: 'bar' }
      )

      expect(result).to be_a(SaltEdge::RequestResult)
      expect(result).to be_success
      expect(result.data).to eq('ok' => true)
      expect(signer).to have_received(:build_headers).with(method: 'post', path: '/v1/consents', body: '{"foo":"bar"}', additional_headers: {})
      expect(a_request(:post, 'https://priora.saltedge.com/v1/consents')).to have_been_made
    end

    it 'supports explicit timeout without changing request behavior' do
      stub_request(:get, 'https://priora.saltedge.com/v1/consents/1/status')
        .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

      result = adapter.request(method: :get, path: '/v1/consents/1/status', timeout: 5)

      expect(result).to be_success
      expect(a_request(:get, 'https://priora.saltedge.com/v1/consents/1/status')).to have_been_made.once
    end

    it 'returns failed RequestResult for non-2xx responses with normalized RequestError' do
      stub_request(:get, 'https://priora.saltedge.com/v1/accounts')
        .to_return(status: 400, body: { 'tppMessages' => [{ 'code' => 'FORMAT_ERROR', 'text' => 'Missing header' }] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = adapter.request(method: :get, path: '/v1/accounts')

      expect(result).to be_failure
      expect(result.error).to be_a(SaltEdge::RequestError)
      expect(result.error.status).to eq(400)
      expect(result.error.code).to eq('FORMAT_ERROR')
      expect(result.error.message).to eq('Missing header')
    end

    it 'returns failed RequestResult on transport errors' do
      stub_timeout_for(:get, 'https://priora.saltedge.com/v1/accounts')

      result = adapter.request(method: :get, path: '/v1/accounts')

      expect(result).to be_failure
      expect(result.error).to be_a(SaltEdge::RequestError)
      expect(result.error.message).to match(/Salt Edge request failed/)
    end

    it 'returns raw_body hash when upstream body is not JSON' do
      stub_request(:get, 'https://priora.saltedge.com/v1/accounts')
        .to_return(status: 200, body: 'OK', headers: { 'Content-Type' => 'text/plain' })

      result = adapter.request(method: :get, path: '/v1/accounts')

      expect(result).to be_success
      expect(result.data).to eq('raw_body' => 'OK')
    end
  end
end
