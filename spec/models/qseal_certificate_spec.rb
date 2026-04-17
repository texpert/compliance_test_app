# frozen_string_literal: true

# == Schema Information
#
# Table name: qseal_certificates
#
#  id                :integer          not null, primary key
#  custom_attributes :json
#  qc_statement_data :json             not null
#  tsp_name          :string           not null
#  provider_id       :integer          not null
#
# Indexes
#
#  index_qseal_certificates_on_provider_id  (provider_id)
#
# Foreign Keys
#
#  provider_id  (provider_id => providers.id)
#
RSpec.describe QsealCertificate, type: :model do
  it { should belong_to(:provider) }
  it { should have_one(:certificate_record).class_name('Certificate').dependent(:destroy) }

  describe 'PSP_ROLES' do
    it 'defines all four PSD2 role codes with correct OIDs and labels' do
      expect(described_class::PSP_ROLES.transform_values { |v| v[:oid] }).to eq(
        'PSP_AS' => '0.4.0.19495.1.1',
        'PSP_PI' => '0.4.0.19495.1.2',
        'PSP_AI' => '0.4.0.19495.1.3',
        'PSP_IC' => '0.4.0.19495.1.4'
      )
      expect(described_class::PSP_ROLES.keys).to match_array(%w[PSP_AS PSP_PI PSP_AI PSP_IC])
      expect(described_class::PSP_ROLES.values).to all(include(:oid, :label))
    end
  end

  describe 'validations' do
    let(:provider) { create(:provider) }

    it 'is invalid with an unrecognized role in qc_statement_data' do
      qseal = QsealCertificate.new(provider: provider, tsp_name: 'Test TSP', qc_statement_data: ['INVALID_ROLE'])
      expect(qseal).not_to be_valid
      expect(qseal.errors[:qc_statement_data]).to be_present
    end

    it 'is valid with a recognized subset of roles' do
      qseal = QsealCertificate.new(provider: provider, tsp_name: 'Test TSP', qc_statement_data: ['PSP_AI', 'PSP_PI'])
      expect(qseal).to be_valid
    end
  end
end
