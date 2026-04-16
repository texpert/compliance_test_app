# frozen_string_literal: true

# == Schema Information
#
# Table name: companies
#
#  id            :integer          not null, primary key
#  address       :string           not null
#  city          :string           not null
#  country_code  :string           not null
#  email         :string           not null
#  name          :string           not null
#  official_name :string
#  phone_number  :string           not null
#  zip_code      :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
RSpec.describe Company, type: :model do
  subject(:company) { build(:company) }

  it { should validate_presence_of(:country_code) }

  it 'validates country_code is a valid ISO 3166-1 alpha-2 code' do
    company.country_code = 'GB'
    expect(company).to be_valid
    company.country_code = 'ZZ'
    expect(company).not_to be_valid
    expect(company.errors[:country_code]).to include('is not a valid ISO 3166-1 alpha-2 country code')
  end

  it 'stores country_code in ISO2 format when created via feature spec' do
    company = Company.create!(name: 'Test', official_name: 'Test Ltd.', email: 'test@example.com', address: '123 St', phone_number: '123', zip_code: '12345', city: 'London', country_code: 'GB')
    expect(company.country_code).to eq('GB')
  end

  it 'persists official_name' do
    company = Company.create!(name: 'Test', official_name: 'Test Ltd.', email: 'test@example.com', address: '123 St', phone_number: '123', zip_code: '12345', city: 'London', country_code: 'GB')
    expect(company.official_name).to eq('Test Ltd.')
  end
end
