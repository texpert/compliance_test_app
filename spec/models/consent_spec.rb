# frozen_string_literal: true

# == Schema Information
#
# Table name: consents
#
#  id                   :integer          not null, primary key
#  callback_error       :text
#  callback_params      :json             not null
#  callback_received_at :datetime
#  status               :string           default("received"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  provider_id          :integer          not null
#  upstream_consent_id  :string
#
# Indexes
#
#  index_consents_on_provider_id        (provider_id)
#  index_consents_on_provider_upstream  (provider_id,upstream_consent_id) UNIQUE
#
# Foreign Keys
#
#  provider_id  (provider_id => providers.id)
#
# Check Constraints
#
#  consents_status_check  (status IN ('accepted','received','valid','partiallyAuthorised','rejected','revokedByPsu','expired','terminatedByTpp'))
#
RSpec.describe Consent, type: :model do
  let(:company) { Company.create!(name: 'Test Company', email: 'test@company.com', address: '123 Main St', phone_number: '+1234567890', zip_code: '12345', city: 'Testville', country_code: 'US') }
  let(:user) { User.create!(name: 'Test User', email: 'user@company.com') }
  let(:provider) { Provider.create!(name: 'Artea Sandbox', code: 'artea_sandbox', company: company, representative: user) }
  let(:other_provider) { Provider.create!(name: 'Other Sandbox', code: 'other_sandbox', company: company, representative: user) }

  describe 'associations and validations' do
    it 'requires unique upstream_consent_id per provider' do
      described_class.create!(
        provider: provider,
        upstream_consent_id: 'consent-1',
        status: Consent::STATUS_RECEIVED
      )

      duplicate = described_class.new(
        provider: provider,
        upstream_consent_id: 'consent-1',
        status: Consent::STATUS_RECEIVED
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:upstream_consent_id]).to include('has already been taken')

      same_upstream_other_provider = described_class.new(
        provider: other_provider,
        upstream_consent_id: 'consent-1',
        status: Consent::STATUS_RECEIVED
      )

      expect(same_upstream_other_provider).to be_valid

      same_upstream_different = described_class.new(
        provider: provider,
        upstream_consent_id: 'consent-2',
        status: Consent::STATUS_RECEIVED
      )

      expect(same_upstream_different).to be_valid
    end

    it 'allows different upstream_consent_id values per provider' do
      described_class.create!(
        provider: provider,
        upstream_consent_id: 'consent-1',
        status: Consent::STATUS_RECEIVED
      )

      another = described_class.new(
        provider: provider,
        upstream_consent_id: 'consent-2',
        status: Consent::STATUS_VALID
      )

      expect(another).to be_valid
    end
  end

  describe 'status enum mapping' do
    it 'supports all documented consent statuses' do
      expected = %w[
        accepted
        received
        valid
        partiallyAuthorised
        rejected
        revokedByPsu
        expired
        terminatedByTpp
      ]

      expect(described_class.statuses.values).to match_array(expected)
    end

    it 'falls back to received for unknown upstream statuses' do
      expect(described_class.status_value('mystery')).to eq(Consent::STATUS_RECEIVED)
    end

    it 'keeps known upstream statuses unchanged' do
      expect(described_class.status_value('partiallyAuthorised')).to eq(Consent::STATUS_PARTIALLY_AUTHORISED)
    end

    it 'enforces consent status at the DB level' do
      now = Time.now.utc.iso8601

      expect do
        described_class.connection.execute(<<~SQL)
          INSERT INTO consents (provider_id, upstream_consent_id, status, callback_params, created_at, updated_at)
          VALUES (#{provider.id}, 'db-consent', 'not-a-real-status', '{}', '#{now}', '#{now}')
        SQL
      end.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end
