# frozen_string_literal: true

FactoryBot.define do
  factory :provider do
    name { 'Artea Sandbox' }
    code { 'artea_sandbox' }
    association :company
    association :representative, factory: :user
  end
end
