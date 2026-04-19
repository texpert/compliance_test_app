# frozen_string_literal: true

class AddRegistrationFieldsToProviders < ActiveRecord::Migration[8.1]
  def change
    add_column :providers, :registration_request_sent_at, :datetime
    add_column :providers, :registered_at, :datetime
  end
end
