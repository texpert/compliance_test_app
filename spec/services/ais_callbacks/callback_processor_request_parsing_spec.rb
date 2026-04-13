# frozen_string_literal: true

RSpec.describe AisCallbacks::CallbackProcessor do
  it 'infers consent and invokes handler when request contains id and code' do
    provider = Provider.create!(name: 'Artea Sandbox', code: 'artea_sandbox')
    consent = provider.consents.create!(upstream_consent_id: 'consent-1', status: Consent::STATUS_RECEIVED)

    env = Rack::MockRequest.env_for("/callback/#{consent.id}?code=abc")
    # Simulate Rails routing: populate path parameters as the router would.
    env['action_dispatch.request.path_parameters'] = { 'id' => consent.id.to_s }
    req = ActionDispatch::Request.new(env)

    handler = instance_double('Handler')
    allow(AisCallbacks::Handlers::AuthorizationCallbackHandler).to receive(:new).and_return(handler)
    allow(handler).to receive(:call).and_return(AisCallbacks::HandlerResult.ok(consent: consent, response_body: {}))

    result = described_class.new.call(request: req)

    expect(result.ok?).to be true
    expect(result.consent).to eq(consent)
  end

  it 'returns missing_state when no state present and consent not found' do
    env = Rack::MockRequest.env_for('/callback')
    req = ActionDispatch::Request.new(env)

    result = described_class.new.call(request: req)

    expect(result.ok?).to be false
    expect(result.http_status).to eq(:bad_request)
    expect(result.error_body).to include('error' => 'missing_state')
  end

  it 'sanitizes request headers — only HTTP_*/CONTENT_* keys, invalid bytes replaced' do
    env = Rack::MockRequest.env_for('/callback')
    env['HTTP_FOO'] = "valid\xFF"
    env['CONTENT_TYPE'] = 'application/json'
    env['RACK_ENV'] = 'test'  # must be excluded
    req = ActionDispatch::Request.new(env)

    processor = described_class.new
    headers = processor.send(:sanitize_headers, req)

    expect(headers.keys).to include('HTTP_FOO', 'CONTENT_TYPE')
    expect(headers.keys).not_to include('RACK_ENV')
    expect(headers['HTTP_FOO'].encoding.name).to eq('UTF-8')
  end
end
