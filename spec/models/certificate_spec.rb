require 'rails_helper'

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
