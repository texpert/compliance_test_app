# frozen_string_literal: true

# == Schema Information
#
# Table name: certificates
#
#  id                :integer          not null, primary key
#  certifiable_type  :string           not null
#  csr               :text
#  issuer_dn         :string
#  not_after         :datetime
#  not_before        :datetime
#  pem_content       :text
#  private_key       :text
#  public_key_hash   :string
#  public_key_pem    :text
#  revocation_reason :string
#  revoked_at        :datetime
#  serial_number     :string           not null
#  status            :string           default("pending"), not null
#  subject           :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  certifiable_id    :integer          not null
#  issuer_id         :integer
#
# Indexes
#
#  index_certificates_on_certifiable_type_and_certifiable_id  (certifiable_type,certifiable_id)
#  index_certificates_on_public_key_hash                      (public_key_hash)
#  index_certificates_on_status                               (status)
#
# Foreign Keys
#
#  issuer_id  (issuer_id => certificates.id)
#
RSpec.describe Certificate, type: :model do
  it { should belong_to(:issuer).class_name('Certificate').optional }
  it { should have_many(:issued_certificates).class_name('Certificate').with_foreign_key(:issuer_id) }

  # Use a valid certifiable for presence validation tests
  let(:certifiable) { CaCertificate.create! }
  subject { described_class.new(subject: 'CN=test', serial_number: '123', certifiable: certifiable, status: 'pending') }

  it { should validate_presence_of(:subject) }
  it { should validate_presence_of(:serial_number) }
  it { should validate_presence_of(:certifiable_type) }
  it { should validate_presence_of(:certifiable_id) }
  it { should validate_presence_of(:status) }

  it 'encrypts private_key' do
    cert = described_class.create!(subject: 'CN=test', serial_number: '123', certifiable: CaCertificate.create!, status: 'pending')
    cert.update!(private_key: 'SECRET')
    raw = described_class.connection.select_value("SELECT private_key FROM certificates WHERE id=#{cert.id}")
    expect(raw).not_to eq('SECRET')
    expect(cert.private_key).to eq('SECRET')
  end
end
