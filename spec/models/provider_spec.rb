# frozen_string_literal: true

# == Schema Information
#
# Table name: providers
#
#  id                :integer          not null, primary key
#  code              :string           not null
#  name              :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  company_id        :integer          not null
#  representative_id :integer          not null
#
# Indexes
#
#  index_providers_on_code               (code) UNIQUE
#  index_providers_on_company_id         (company_id)
#  index_providers_on_representative_id  (representative_id)
#
# Foreign Keys
#
#  company_id         (company_id => companies.id)
#  representative_id  (representative_id => users.id)
#
RSpec.describe Provider, type: :model do
  subject(:provider) { build(:provider) }

  it { should belong_to(:company) }
  it { should belong_to(:representative).class_name('User') }
  it { should have_many(:qseal_certificates) }
  it { should have_many(:certificates).through(:qseal_certificates).source(:certificate_record) }

  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:code) }

  it 'validates code uniqueness' do
    create(:provider, code: 'unique_code')
    duplicate = build(:provider, code: 'unique_code')
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:code]).to include('has already been taken')
  end

  describe '.ransackable_attributes' do
    it 'includes expected attributes' do
      expect(described_class.ransackable_attributes).to include('name', 'code', 'company_id', 'representative_id')
    end
  end

  describe '.ransackable_associations' do
    it 'includes company and representative' do
      expect(described_class.ransackable_associations).to include('company', 'representative')
    end
  end
end
