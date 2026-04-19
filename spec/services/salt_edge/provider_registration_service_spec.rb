# frozen_string_literal: true

RSpec.describe SaltEdge::ProviderRegistrationService do
  include ActiveSupport::Testing::TimeHelpers

  let(:company)  { create(:company) }
  let(:user)     { create(:user) }
  let(:provider) { create(:provider, company: company, representative: user) }

  let(:adapter_config) { instance_double(SaltEdge::Config, api_base_url: 'https://priora.saltedge.com', http_timeout: 30) }
  let(:signer)         { instance_double(SaltEdge::SignatureBuilder) }
  let(:request_adapter) do
    SaltEdge::RequestAdapter.new(config: adapter_config, signer: signer, client: HTTPX)
  end

  let(:signed_headers) do
    {
      'Signature'                 => 'sig',
      'Digest'                    => 'SHA-256=abc',
      'X-Request-ID'              => 'req-1',
      'Date'                      => 'Sun, 19 Apr 2026 12:00:00 GMT',
      'TPP-Signature-Certificate' => 'cert-b64'
    }
  end

  subject(:service) { described_class.new(request_adapter: request_adapter) }

  before do
    allow(signer).to receive(:build_headers).and_return(signed_headers)
    Flipper.enable(:ais_event_recording)
  end

  let(:ca_cert) { CaRootCertificateCreator.create!(key_size: 1024).first }

  let(:qseal_cert) do
    QsealCertificateCreator.create!(provider: provider, ca_certificate: ca_cert, name: 'Test QSeal').first
  end

  describe '#register' do
    context 'when the registration request succeeds' do
      let(:upstream_response) do
        { 'status' => 'pending', 'message' => 'Registration submitted. Confirmation email sent.' }
      end

      before do
        stub_request(:post, 'https://priora.saltedge.com/api/berlingroup/v1/tpp/register')
          .to_return(status: 200, body: upstream_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'posts to the TPP register endpoint with company and representative data' do
        service.register(provider: provider, representative: user, certificate: qseal_cert)

        expect(
          a_request(:post, 'https://priora.saltedge.com/api/berlingroup/v1/tpp/register').with { |req|
            body = JSON.parse(req.body)
            body.dig('certificate', 'type') == 'qseal' &&
              body.dig('certificate', 'name') == 'Test QSeal' &&
              body.dig('company', 'name') == company.name &&
              body.dig('company', 'email') == company.email &&
              body.dig('representative', 'name') == user.name &&
              body.dig('representative', 'email') == user.email
          }
        ).to have_been_made
      end

      it 'returns a successful result' do
        result = service.register(provider: provider, representative: user, certificate: qseal_cert)

        expect(result).to be_success
        expect(result.data).to eq(upstream_response)
      end

      it 'stamps registration_request_sent_at on the provider' do
        travel_to(Time.utc(2026, 4, 19, 12, 0, 0)) do
          service.register(provider: provider, representative: user, certificate: qseal_cert)
          expect(provider.reload.registration_request_sent_at).to eq(Time.utc(2026, 4, 19, 12, 0, 0))
        end
      end

      it 'records a tpp_registration_request Event' do
        expect {
          service.register(provider: provider, representative: user, certificate: qseal_cert)
        }.to change { Event.where(event_type: 'tpp_registration_request', provider: provider).count }.by(1)
      end
    end

    context 'when the upstream returns a non-2xx response' do
      before do
        stub_request(:post, 'https://priora.saltedge.com/api/berlingroup/v1/tpp/register')
          .to_return(
            status: 422,
            body: { 'tppMessages' => [{ 'text' => 'CERTIFICATE_INVALID', 'code' => 'CERTIFICATE_INVALID' }] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns a failure result with error message' do
        result = service.register(provider: provider, representative: user, certificate: qseal_cert)

        expect(result).to be_failure
        expect(result.error.message).to eq('CERTIFICATE_INVALID')
      end

      it 'does not update registration_request_sent_at' do
        service.register(provider: provider, representative: user, certificate: qseal_cert)

        expect(provider.reload.registration_request_sent_at).to be_nil
      end

      it 'still records a tpp_registration_request Event with error body' do
        service.register(provider: provider, representative: user, certificate: qseal_cert)

        event = Event.where(event_type: 'tpp_registration_request', provider: provider).last
        expect(event).to be_present
        expect(event.response_body['error']).to be_present
      end
    end

    context 'when no issued QSeal certificate exists for the provider' do
      it 'returns a failure result without making any HTTP request' do
        result = service.register(provider: provider, representative: user)

        expect(result).to be_failure
        expect(result.error.message).to match(/No issued QSeal certificate/)
        expect(a_request(:post, 'https://priora.saltedge.com/api/berlingroup/v1/tpp/register')).not_to have_been_made
      end
    end

    context 'when the provider has multiple issued certs and none is specified' do
      let(:qseal_cert_2) do
        QsealCertificateCreator.create!(provider: provider, ca_certificate: ca_cert, name: 'Newer QSeal').first
      end

      before do
        qseal_cert    # create older cert first
        qseal_cert_2  # then newer one
        stub_request(:post, 'https://priora.saltedge.com/api/berlingroup/v1/tpp/register')
          .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
      end

      it 'defaults to the most recently created issued certificate' do
        service.register(provider: provider, representative: user)

        expect(
          a_request(:post, 'https://priora.saltedge.com/api/berlingroup/v1/tpp/register').with { |req|
            JSON.parse(req.body).dig('certificate', 'name') == 'Newer QSeal'
          }
        ).to have_been_made
      end
    end
  end
end
