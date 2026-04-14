# frozen_string_literal: true

class CompanyUser < ApplicationRecord
  belongs_to :company
  belongs_to :user
end
