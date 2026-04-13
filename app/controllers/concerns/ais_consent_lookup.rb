# frozen_string_literal: true

# Shared before_action for AIS controllers that operate on a specific consent.
# Sets @consent and halts with an appropriate JSON error when the consent is
# missing, has no upstream id, or is not in a fetchable state.
module AisConsentLookup
  extend ActiveSupport::Concern

  included do
    before_action :load_and_validate_consent
  end

  private

  def load_and_validate_consent
    @consent = Consent.find_by(id: params[:id])
    return render(json: { error: 'consent_not_found' }, status: :not_found) unless @consent

    unless @consent.upstream_consent_id.present?
      return render(json: { error: 'missing_upstream_consent_id' }, status: :unprocessable_content)
    end

    unless @consent.status_valid?
      render(json: { error: 'consent_not_valid', consent_status: @consent.status }, status: :forbidden) and return
    end
  end
end
