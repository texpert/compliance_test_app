# frozen_string_literal: true

# == Schema Information
#
# Table name: companies_users
#
#  company_id :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_companies_users_on_company_id              (company_id)
#  index_companies_users_on_company_id_and_user_id  (company_id,user_id) UNIQUE
#  index_companies_users_on_user_id                 (user_id)
#
# Foreign Keys
#
#  company_id  (company_id => companies.id)
#  user_id     (user_id => users.id)
#
class CompanyUser < ApplicationRecord
  self.table_name = 'companies_users'

  belongs_to :company
  belongs_to :user
end
