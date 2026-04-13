# frozen_string_literal: true

RSpec.describe 'AisCallbacks', type: :request do
  describe 'GET /callback/:id when consent not found' do
    before { Flipper.enable(:ais_event_recording) }

    it 'records an Event and returns consent_not_found' do
      # Use a non-existent consent id
      get ais_callback_path(9_999_999), params: { state: 'nope', code: 'auth-code' }

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq('error' => 'consent_not_found')

      event = Event.order(:created_at).last
      expect(event).to be_present
      expect(event.event_type).to eq('callback')
      expect(event.request_body).to include('event_type' => 'authorization_callback', 'code' => 'auth-code', 'state' => 'nope')
      expect(event.response_body).to include('error' => 'consent_not_found')
    end
  end
end
