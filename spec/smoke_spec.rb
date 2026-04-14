# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bootstrap" do
  it "loads the Rails app and runs specs" do
    expect(Rails.application).to be_present
  end
end
