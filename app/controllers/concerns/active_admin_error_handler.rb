# frozen_string_literal: true

module ActiveAdminErrorHandler
  extend ActiveSupport::Concern

  # Prepend allows us to call 'super' to trigger the original logic
  # while still wrapping it in our rescue block.
  def create
    super
  rescue StandardError => e
    handle_global_error(e, :new)
  end

  def update
    super
  rescue StandardError => e
    handle_global_error(e, :edit)
  end

  private

  def handle_global_error(exception, render_action)
    resource.errors.add(:base, "System error: #{exception.message}")
    flash[:error] = 'The operation could not be completed.'
    render render_action
  end
end
