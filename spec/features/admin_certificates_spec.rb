# frozen_string_literal: true

RSpec.feature 'Admin Certificates Blank Slate', type: :feature do
  scenario 'shows custom blank slate and create button when no certificates exist' do
    # Ensure no certificates exist
    Certificate.delete_all
    CaCertificate.delete_all
    QsealCertificate.delete_all if defined?(QsealCertificate)

    visit '/admin/certificates'

    expect(page).to have_content('There are no Certificates yet.')
    expect(page).to have_button('Create a CA Root certificate')

    # Check for ActiveAdmin layout elements
    expect(page).to have_selector('body.active_admin')
    expect(page).to have_selector('div#active_admin_content')
    expect(page).to have_selector('div.blank_slate_container')
    expect(page).to have_selector('span.blank_slate')
  end

  scenario 'shows create CA Root certificate button as action item when certificates exist' do
    Certificate.delete_all
    CaCertificate.delete_all
    QsealCertificate.delete_all if defined?(QsealCertificate)

    # Create a dummy certificate with valid PEM
    require 'openssl'
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = OpenSSL::X509::Name.parse('/C=RO/O=TestCA/CN=Test CA')
    cert.issuer = cert.subject
    cert.public_key = key.public_key
    cert.not_before = Time.now
    cert.not_after = Time.now + 1.day
    cert.sign(key, OpenSSL::Digest::SHA256.new)
    ca = CaCertificate.create!
    Certificate.create!(certifiable: ca, pem_content: cert.to_pem, private_key: key.to_pem, subject: cert.subject.to_s, issuer_dn: cert.issuer.to_s, serial_number: cert.serial.to_s, not_before: cert.not_before, not_after: cert.not_after, status: 'issued')

    visit '/admin/certificates'
    expect(page).to have_button('Create a CA Root certificate')
  end

  scenario 'creates a CA Root certificate when the button is clicked' do
    Certificate.delete_all
    CaCertificate.delete_all
    QsealCertificate.delete_all if defined?(QsealCertificate)

    visit '/admin/certificates'
    expect(page).to have_button('Create a CA Root certificate')
    within('div.blank_slate_container') do
      click_button 'Create a CA Root certificate'
    end
    expect(page).to have_content('CA Root certificate created successfully.')
    expect(page).to have_content('SaltEdge CA Authority')
    expect(Certificate.where("subject LIKE ?", "%SaltEdge CA Authority%")).to exist
  end
end
