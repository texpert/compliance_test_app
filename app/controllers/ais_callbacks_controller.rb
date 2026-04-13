# frozen_string_literal: true

class AisCallbacksController < ApplicationController
  skip_before_action :verify_browser, raise: false

  def show
    # Delegate the full request to the processor. The processor infers consent,
    # callback_state, code, and other derived values — keeping the controller thin.
    result = callback_processor.call(request: request)

    return redirect_to(ais_consent_path(result.consent)) if result.ok?

    render json: result.error_body, status: result.http_status
  end

  private

  def callback_processor
    @callback_processor ||= AisCallbacks::CallbackProcessor.new
  end
end
