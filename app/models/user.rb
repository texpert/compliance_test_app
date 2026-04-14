# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id         :integer          not null, primary key
#  email      :string           not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class User < ApplicationRecord
  has_many :company_users
  has_many :companies, through: :company_users
  has_many :represented_providers, class_name: 'Provider', foreign_key: :representative_id

  validates :name, :email, presence: true
end
