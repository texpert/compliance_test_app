# frozen_string_literal: true

class AisConsentsController < ApplicationController
  skip_before_action :verify_browser, raise: false

  def index
    consents = Consent.includes(:provider).order(created_at: :desc)
    render json: {
      consents: consents.map do |consent|
        {
          id: consent.id,
          status: consent.status,
          upstream_consent_id: consent.upstream_consent_id,
          provider_code: consent.provider.code,
          created_at: consent.created_at
        }
      end
    }
  end

  def create
    provider_attrs = {
      code: params.dig(:provider, :code) || 'artea_sandbox',
      name: params.dig(:provider, :name) || 'Artea Sandbox',
      company_id: params.dig(:provider, :company_id),
      representative_id: params.dig(:provider, :representative_id)
    }.compact

    provider = Provider.find_by(code: provider_attrs[:code])
    unless provider
      provider = Provider.create!(provider_attrs)
    end

    consent = provider.consents.create!(
      upstream_consent_id: nil,
      status: Consent::STATUS_RECEIVED,
      callback_params: {}
    )

    consent_response = consent_service.create_and_persist_consent(consent: consent)

    begin
      Event.record(
        event_type: 'consent_create',
        provider: provider,
        consent: consent,
        request_body: { consent_id: consent.id },
        response_body: consent_response
      )
    rescue StandardError => e
      Rails.logger.error("Event.record failed for consent #{consent.id}: #{e.message}")
    end

    redirect_to consent_response.fetch('sca_redirect_url'), allow_other_host: true
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: 'consent_persist_failed', message: e.message }, status: :unprocessable_content
  rescue SaltEdge::RequestError => e
    render json: { error: 'consent_creation_failed', message: e.message }, status: :bad_gateway
  end

  def show
    consent = Consent.includes(:provider, :events).find_by(id: params[:id])
    return render(json: { error: 'consent_not_found' }, status: :not_found) unless consent

    render json: {
      id: consent.id,
      provider: {
        id: consent.provider.id,
        code: consent.provider.code,
        name: consent.provider.name
      },
      upstream_consent_id: consent.upstream_consent_id,
      consent_status: consent.status,
      callback_received_at: consent.callback_received_at,
      callback_error: consent.callback_error,
      callback_params: consent.callback_params,
      events: consent.events.order(:occurred_at).map do |event|
        {
          event_type: event.event_type,
          provider_id: event.provider_id,
          consent_id: event.consent_id,
          request_headers: event.request_headers,
          request_body: event.request_body,
          response_headers: event.response_headers,
          response_body: event.response_body,
          occurred_at: event.occurred_at
        }
      end
    }
  end

  private

  def consent_service
    @consent_service ||= SaltEdge::ConsentService.new
  end
end
