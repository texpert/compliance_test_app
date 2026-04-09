# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HttpxClient do
  RequestStruct = Struct.new(:verb, :uri, :headers, :body)
  ResponseStruct = Struct.new(:status, :headers, :body)

  before do
    described_class.instance_variable_set(:@session, nil)
  end

  describe '.session' do
    it 'returns an HTTPX session object' do
      expect(described_class.session).to be_a(HTTPX::Session)
    end

    it 'memoizes the HTTPX callback session' do
      session_builder = instance_double('HTTPXSessionBuilder')

      allow(HTTPX).to receive(:plugin).with(:callbacks).and_return(session_builder)
      allow(session_builder).to receive(:on_request_started).and_return(session_builder)
      allow(session_builder).to receive(:on_response_completed).and_return(session_builder)
      allow(session_builder).to receive(:on_request_error).and_return(session_builder)

      first = described_class.session
      second = described_class.session

      expect(first).to eq(session_builder)
      expect(second).to eq(session_builder)
      expect(HTTPX).to have_received(:plugin).once
    end

    it 'loads the callbacks plugin on the session' do
      session = described_class.session

      expect(session.class.ancestors.map(&:to_s)).to include('HTTPX::Plugins::Callbacks::InstanceMethods')
    end
  end

  describe 'logging callbacks' do
    let(:request) { RequestStruct.new('POST', 'https://example.test/consents', { 'x-id' => '1' }, '{}') }

    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
      allow(SecureRandom).to receive(:uuid).and_return('uid-123')
      allow(described_class).to receive(:determine_caller_name).and_return('SpecCaller')
    end

    it 'logs request start only once for duplicate callback invocations' do
      described_class.send(:handle_request_started, request)
      described_class.send(:handle_request_started, request)

      expect(Rails.logger).to have_received(:info).once
      expect(request.instance_variable_get(:@log_trace_ids)).to eq({ uid: 'uid-123' })
      expect(request.instance_variable_get(:@log_prefix)).to include('service=HTTPX, caller=SpecCaller, method=POST')
    end

    it 'logs request start message with timestamp, headers, and body' do
      described_class.send(:handle_request_started, request)

      expect(Rails.logger).to have_received(:info).with(
        a_string_matching(/Request started: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/)
      )
      expect(Rails.logger).to have_received(:info).with(include('Headers:'))
      expect(Rails.logger).to have_received(:info).with(include('Body: {}'))
    end

    it 'logs successful responses as info with status and duration' do
      described_class.send(:handle_request_started, request)
      response = ResponseStruct.new(200, { 'content-type' => 'application/json' }, '{"ok":true}')

      described_class.send(:handle_response_completed, request, response)

      expect(Rails.logger).to have_received(:info).with(include('Response completed:'))
      expect(Rails.logger).to have_received(:info).with(include('status=200'))
      expect(Rails.logger).to have_received(:info).with(a_string_matching(/Duration: \d+\.\d+s/))
    end

    it 'logs completed response only once for duplicate callback invocations' do
      described_class.send(:handle_request_started, request)
      response = ResponseStruct.new(200, { 'content-type' => 'application/json' }, '{"ok":true}')

      described_class.send(:handle_response_completed, request, response)
      described_class.send(:handle_response_completed, request, response)

      expect(Rails.logger).to have_received(:info).with(include('Response completed:')).once
    end

    it 'logs non-2xx responses as errors' do
      described_class.send(:handle_request_started, request)
      response = ResponseStruct.new(400, { 'content-type' => 'application/json' }, '{"error":"bad_request"}')

      described_class.send(:handle_response_completed, request, response)

      expect(Rails.logger).to have_received(:error).with(include('HTTPX request failed'))
      expect(Rails.logger).to have_received(:error).with(include('status=400'))
    end

    it 'logs request errors' do
      described_class.send(:handle_request_started, request)
      error = StandardError.new('connection dropped')

      described_class.send(:handle_request_error, request, error)

      expect(Rails.logger).to have_received(:error).with(include('HTTPX request error'))
      expect(Rails.logger).to have_received(:error).with(include('error_class=StandardError'))
      expect(Rails.logger).to have_received(:error).with(include('error_message=connection dropped'))
    end

    it 'logs request error only once for duplicate callback invocations' do
      described_class.send(:handle_request_started, request)
      error = StandardError.new('connection dropped')

      described_class.send(:handle_request_error, request, error)
      described_class.send(:handle_request_error, request, error)

      expect(Rails.logger).to have_received(:error).with(include('HTTPX request error')).once
    end
  end

  describe '.determine_caller_name' do
    it 'returns a non-empty caller name string' do
      expect(described_class.send(:determine_caller_name)).to be_a(String)
      expect(described_class.send(:determine_caller_name)).not_to be_empty
    end
  end
end
