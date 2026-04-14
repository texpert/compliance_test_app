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
  has_many :company_users, dependent: :destroy
  has_many :companies, through: :company_users
  has_many :represented_providers, class_name: 'Provider', foreign_key: :representative_id

  validates :name, :email, presence: true

  def self.ransackable_attributes(auth_object = nil)
    %w[id name email created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[represented_providers]
  end
end
