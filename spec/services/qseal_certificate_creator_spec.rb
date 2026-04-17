# frozen_string_literal: true

RSpec.describe QsealCertificateCreator do
  let!(:provider) { create(:provider) }
  let!(:ca_cert_record) { CaRootCertificateCreator.create!(name: 'Test CA Root').first }

  describe '.create!' do
    subject(:result) { described_class.create!(provider: provider, ca_certificate: ca_cert_record, name: 'My QSeal') }

    it 'returns a persisted Certificate and QsealCertificate' do
      cert, qseal = result
      expect(cert).to be_persisted
      expect(qseal).to be_persisted
    end

    it 'links the certificate to the qseal record as certifiable' do
      cert, qseal = result
      expect(cert.certifiable).to eq(qseal)
    end

    it 'links the qseal certificate to the provider' do
      _cert, qseal = result
      expect(qseal.provider).to eq(provider)
    end

    it 'stores the certificate name' do
      cert, _qseal = result
      expect(cert.name).to eq('My QSeal')
    end

    it 'generates and stores a valid 2048-bit private key' do
      cert, _qseal = result
      expect(cert.private_key).to be_present
      key = OpenSSL::PKey::RSA.new(cert.private_key)
      expect(key.n.num_bits).to eq(2048)
    end

    it 'generates and stores the CSR' do
      cert, _qseal = result
      expect(cert.csr).to be_present
      expect { OpenSSL::X509::Request.new(cert.csr) }.not_to raise_error
    end

    it 'stores valid PEM content for the signed certificate' do
      cert, _qseal = result
      expect(cert.pem_content).to be_present
      expect { OpenSSL::X509::Certificate.new(cert.pem_content) }.not_to raise_error
    end

    it 'auto-extracts serial number from PEM content' do
      cert, _qseal = result
      expect(cert.serial_number).to be_present
    end

    it 'derives and stores the public key from the signed certificate' do
      cert, _qseal = result
      expect(cert.reload.public_key_pem).to be_present
      expect(cert.public_key_pem).to start_with('-----BEGIN PUBLIC KEY-----')
      parsed = OpenSSL::X509::Certificate.new(cert.pem_content)
      expect(cert.public_key_pem).to eq(parsed.public_key.to_pem)
    end

    it 'sets the issuer to the CA certificate record' do
      cert, _qseal = result
      expect(cert.issuer).to eq(ca_cert_record)
    end

    it 'sets status to issued' do
      cert, _qseal = result
      expect(cert.status).to eq('issued')
    end

    it 'sets tsp_name from company name' do
      _cert, qseal = result
      expected = provider.company.official_name.presence || provider.company.name
      expect(qseal.tsp_name).to eq(expected)
    end

    it 'stores all PSP roles by default in qc_statement_data' do
      _cert, qseal = result
      expect(qseal.qc_statement_data).to match_array(QsealCertificate::PSP_ROLES.keys)
    end

    it 'derives subject CN from company name (spaces/hyphens to underscores, downcased)' do
      cert, _qseal = result
      parsed = OpenSSL::X509::Certificate.new(cert.pem_content)
      cn = parsed.subject.to_a.find { |name, _val, _type| name == 'CN' }&.at(1)
      expected_out_name = provider.company.name.tr(' ', '_').tr('-', '_').downcase
      expect(cn).to eq("#{expected_out_name} TEST TPP")
    end

    it 'signs the certificate with the provided CA' do
      cert, _qseal = result
      parsed = OpenSSL::X509::Certificate.new(cert.pem_content)
      ca_parsed = OpenSSL::X509::Certificate.new(ca_cert_record.pem_content)
      expect(parsed.verify(ca_parsed.public_key)).to be true
    end

    it 'embeds the qcStatements extension in the certificate' do
      cert, _qseal = result
      parsed = OpenSSL::X509::Certificate.new(cert.pem_content)
      qc_ext = parsed.extensions.find { |e| e.oid == 'qcStatements' || e.oid == '1.3.6.1.5.5.7.1.3' }
      expect(qc_ext).not_to be_nil
    end

    context 'with a custom subset of roles' do
      subject(:result) do
        described_class.create!(
          provider: provider,
          ca_certificate: ca_cert_record,
          name: 'AISP Only',
          roles: ['PSP_AI']
        )
      end

      it 'stores only the selected roles' do
        _cert, qseal = result
        expect(qseal.qc_statement_data).to eq(['PSP_AI'])
      end

      it 'still embeds the qcStatements extension' do
        cert, _qseal = result
        parsed = OpenSSL::X509::Certificate.new(cert.pem_content)
        oids = parsed.extensions.map(&:oid)
        expect(oids).to include('qcStatements').or include('1.3.6.1.5.5.7.1.3')
      end
    end

    context 'when CA pem_content is invalid' do
      let!(:ca_cert_record) do
        cert, _ca = CaRootCertificateCreator.create!(name: 'Bad CA')
        cert.update_columns(pem_content: 'not-a-cert')
        cert
      end

      it 'raises an error without persisting any records' do
        prior_qseal_count = QsealCertificate.count
        expect {
          described_class.create!(provider: provider, ca_certificate: ca_cert_record, name: 'Fail')
        }.to raise_error(OpenSSL::OpenSSLError)
        expect(QsealCertificate.count).to eq(prior_qseal_count)
      end
    end
  end
end
