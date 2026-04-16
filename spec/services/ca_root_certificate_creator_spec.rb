# frozen_string_literal: true

RSpec.describe CaRootCertificateCreator do
  it 'creates a valid CA Root certificate and CaCertificate' do
    cert, ca = described_class.create!
    expect(cert).to be_persisted
    expect(ca).to be_persisted
    expect(cert.certifiable).to eq(ca)
    expect(ca.is_root).to be true
    expect(cert.name).to eq('SaltEdge CA Root')
    expect(cert.subject).to include('SaltEdge CA Authority')
    expect(cert.pem_content).to be_present
    expect(cert.private_key).to be_present
    # Validate with validator
    expect(CaRootCertificateValidator.valid?(cert.pem_content)).to be true
  end
end
