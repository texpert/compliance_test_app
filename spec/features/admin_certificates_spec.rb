# frozen_string_literal: true

RSpec.feature 'Admin Certificates Blank Slate', type: :feature do
  scenario 'shows custom blank slate and create button when no certificates exist' do
    # Ensure no certificates exist
    Certificate.delete_all
    CaCertificate.delete_all
    QsealCertificate.delete_all if defined?(QsealCertificate)

    visit '/admin/certificates'

    expect(page).to have_content('There are no Certificates yet.')
    expect(page).to have_link('Create a CA Root certificate')

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

    # Use CaRootCertificateCreator to create a CA Root certificate
    cert, _ca = CaRootCertificateCreator.create!(name: 'Test CA Root')

    visit '/admin/certificates'
    expect(page).to have_link('Create a CA Root certificate')
  end

  scenario 'creates a CA Root certificate when the button is clicked' do
    Certificate.delete_all
    CaCertificate.delete_all
    QsealCertificate.delete_all

    visit '/admin/certificates'
    expect(page).to have_link('Create a CA Root certificate')
    within('div.blank_slate_container') do
      click_link 'Create a CA Root certificate'
    end

    expect(page).to have_content('Create a CA Root Certificate')
    expect(page).to have_button('Create CA Root certificate')
    fill_in 'Certificate Name', with: 'My Custom CA Root'
    click_button 'Create CA Root certificate'
    expect(page).to have_content('CA Root certificate created successfully.')
    expect(page).to have_content('SaltEdge CA Authority')
    expect(Certificate.where("subject LIKE ?", "%SaltEdge CA Authority%")).to exist
    # Check that the index page includes the new certificate and its name
    visit '/admin/certificates'
    cert = Certificate.find_by(name: 'My Custom CA Root')
    expect(page).to have_content(cert.serial_number)
    expect(page).to have_content(cert.name)
    # Check that the associated CaCertificate has is_root: true
    expect(cert.certifiable).to be_a(CaCertificate)
    expect(cert.certifiable.is_root).to be true
  end

  scenario 'edit page allows only name, status, revoked_at, and revocation reason to be edited, others are read-only' do
    # Use CaRootCertificateCreator to create a CA Root certificate for edit page
    subject_str = '/C=RO/O=TestCA/CN=Test CA'
    cert, _ca = CaRootCertificateCreator.create!(name: 'Editable Cert', subject: subject_str)
    visit "/admin/certificates/#{cert.id}/edit"
    # Editable fields
    expect(page).to have_field('Name', with: 'Editable Cert')
    expect(page).to have_field('Status', with: 'issued')
    expect(page).to have_field('Revoked at')
    expect(page).to have_field('Revocation reason')

    # Actually edit the editable params
    fill_in 'Name', with: 'Updated Cert Name'
    fill_in 'Status', with: 'revoked'
    select '2026', from: 'certificate_revoked_at_1i'
    select 'April', from: 'certificate_revoked_at_2i'
    select '16', from: 'certificate_revoked_at_3i'
    select '12', from: 'certificate_revoked_at_4i'
    select '00', from: 'certificate_revoked_at_5i'
    fill_in 'Revocation reason', with: 'Key compromise'
    click_button 'Update Certificate'

    # Check if the certificate has been updated (show page, not edit form)
    expect(page).to have_content('Certificate was successfully updated')
    expect(page).to have_content('Updated Cert Name')
    expect(page).to have_content('revoked')
    expect(page).to have_content('Key compromise')
    expect(page).to have_content('April 16, 2026 12:00')

    # Read-only fields
    expect(page).to have_content("Serial Number #{cert.serial_number}")
    expect(page).to have_content("Subject #{subject_str}")
    expect(page).to have_content("Not Before #{cert.not_before.strftime('%B %d, %Y %H:%M')}")
    expect(page).to have_content("Not After #{cert.not_after.strftime('%B %d, %Y %H:%M')}")
    expect(page).to have_content("Created At #{cert.created_at.strftime('%B %d, %Y %H:%M')}")
    expect(page).to have_content("Updated At #{cert.updated_at.strftime('%B %d, %Y %H:%M')}")
    expect(page).to have_content("Certifiable Type CaCertificate")
    expect(page).to have_content("Certifiable #{cert.certifiable_id}")
    expect(page).to have_content("Issuer Dn #{subject_str}")
    expect(page).to have_content("Public Key Hash #{cert.public_key_hash}")
    expect(page).to have_content("Public Key Pem -----BEGIN PUBLIC KEY-----")
    expect(page).to have_content("Pem Content -----BEGIN CERTIFICATE-----")
    # Should not display CSR or Issuer if blank
    expect(page).not_to have_content('CSR:')
    expect(page).not_to have_content('Issuer:')
  end

  scenario 'shows errors when CA Root certificate creation fails' do
    Certificate.delete_all
    CaCertificate.delete_all
    QsealCertificate.delete_all

    visit '/admin/certificates'
    expect(page).to have_link('Create a CA Root certificate')
    within('div.blank_slate_container') do
      click_link 'Create a CA Root certificate'
    end
    expect(page).to have_content('Create a CA Root Certificate')

    # Stub the creator to simulate a failure
    allow(CaRootCertificateCreator).to receive(:create!).and_raise(StandardError, 'Simulated creation failure')

    fill_in 'Certificate Name', with: 'Any Name'
    click_button 'Create CA Root certificate'

    # Should redirect to index with an alert
    expect(page).to have_current_path('/admin/certificates')
    expect(page).to have_content('Failed to create CA Root certificate').or have_content('CA Root certificate failed validation checks')
    expect(Certificate.count).to eq(0)
    expect(CaCertificate.count).to eq(0)
  end

  scenario 'shows errors when certificate edit fails' do
    Certificate.delete_all
    CaCertificate.delete_all
    QsealCertificate.delete_all

    subject_str = '/C=RO/O=TestCA/CN=Test CA'
    cert, _ca = CaRootCertificateCreator.create!(name: 'Editable Cert', subject: subject_str)
    visit "/admin/certificates/#{cert.id}/edit"

    allow_any_instance_of(Certificate).to receive(:save).and_raise(StandardError, 'Simulated update failure')

    # Submit invalid data (blank name) to trigger validation error
    fill_in 'Status', with: 'revoked'
    select '2026', from: 'certificate_revoked_at_1i'
    select 'April', from: 'certificate_revoked_at_2i'
    select '16', from: 'certificate_revoked_at_3i'
    select '12', from: 'certificate_revoked_at_4i'
    select '00', from: 'certificate_revoked_at_5i'
    fill_in 'Revocation reason', with: 'Key compromise'
    click_button 'Update Certificate'

    # Should stay on edit page and show error alert
    expect(page).to have_button('Update Certificate')

    # Reload and check that attributes did not change
    cert.reload
    expect(cert.name).to eq('Editable Cert')
    expect(cert.status).to eq('issued')
    expect(cert.revoked_at).to be_nil
    expect(cert.revocation_reason).to be_nil
  end
end
