# frozen_string_literal: true

RSpec.describe 'Admin Provider management', type: :feature do
  let!(:company) { create(:company, name: 'Acme Corp', email: 'acme@example.com') }
  let!(:user) { create(:user, name: 'Alice', email: 'alice@example.com') }

  before { company.users << user }

  scenario 'Providers panel is visible on Company show page with Create Provider link' do
    visit admin_company_path(company)
    within('#providers_panel') do
      expect(page).to have_content('Providers')
      expect(page).to have_link('Create Provider')
    end
  end

  scenario 'No "New Provider" or "Create one" link on standalone providers index' do
    visit admin_providers_path
    expect(page).not_to have_link('New Provider')
    expect(page).not_to have_link('Create one')
    expect(page).to have_content("Create providers from a Company's page.")
  end

  scenario 'New provider form is pre-filled with defaults from company' do
    visit new_admin_company_provider_path(company)
    expect(find_field('Name').value).to eq('Acme Corp TPP')
    expect(find_field('Code').value).to eq('acme_corp')
  end

  scenario 'Code default replaces spaces and hyphens with underscores and lowercases' do
    company2 = create(:company, name: 'My-Company Name', email: 'my@example.com')
    user2 = create(:user, name: 'Bob', email: 'bob@example.com')
    company2.users << user2

    visit new_admin_company_provider_path(company2)
    expect(find_field('Code').value).to eq('my_company_name')
  end

  scenario 'Representative is auto-selected when company has exactly one user' do
    visit new_admin_company_provider_path(company)
    expect(page).to have_select('Representative', selected: 'Alice')
  end

  scenario 'Representative is not auto-selected when company has multiple users' do
    user2 = create(:user, name: 'Bob', email: 'bob@example.com')
    company.users << user2

    visit new_admin_company_provider_path(company)
    expect(page).to have_select('Representative', options: ['', 'Alice', 'Bob'])
  end

  scenario 'Admin can create a provider from company show page' do
    visit new_admin_company_provider_path(company)
    # Defaults already filled; representative auto-selected (1 user)
    click_button 'Create Provider'
    expect(page).to have_content('Provider was successfully created')
    expect(page).to have_content('Acme Corp TPP')
    expect(page).to have_content('acme_corp')
  end

  scenario 'Admin can create a provider with custom name and code' do
    visit new_admin_company_provider_path(company)
    fill_in 'Name', with: 'Custom TPP'
    fill_in 'Code', with: 'custom_tpp'
    click_button 'Create Provider'
    expect(page).to have_content('Provider was successfully created')
    expect(page).to have_content('Custom TPP')
    expect(Provider.last.code).to eq('custom_tpp')
  end

  scenario 'Created provider appears in company providers panel' do
    create(:provider, name: 'Acme TPP', code: 'acme_tpp', company: company, representative: user)
    visit admin_company_path(company)
    within('#providers_panel') do
      expect(page).to have_content('Acme TPP')
      expect(page).to have_content('acme_tpp')
      expect(page).to have_content('Alice')
    end
  end

  scenario 'Admin can view providers index' do
    create(:provider, name: 'Acme TPP', code: 'acme_tpp', company: company, representative: user)
    visit admin_providers_path
    expect(page).to have_content('Acme TPP')
    expect(page).to have_content('acme_tpp')
  end

  scenario 'Admin can view a provider show page' do
    provider = create(:provider, name: 'Acme TPP', code: 'acme_tpp', company: company, representative: user)
    visit admin_provider_path(provider)
    expect(page).to have_content('Acme TPP')
    expect(page).to have_content('acme_tpp')
    expect(page).to have_link('Edit Provider')
    expect(page).to have_link('Delete Provider')
  end

  scenario 'Admin can edit a provider' do
    provider = create(:provider, name: 'Old Name', code: 'old_code', company: company, representative: user)
    visit edit_admin_provider_path(provider)
    fill_in 'Name', with: 'New Name'
    fill_in 'Code', with: 'new_code'
    click_button 'Update Provider'
    expect(page).to have_content('Provider was successfully updated')
    expect(page).to have_content('New Name')
    expect(page).to have_content('new_code')
  end

  scenario 'Admin can delete a provider from providers panel', js: true do
    create(:provider, name: 'ToDelete', code: 'to_delete', company: company, representative: user)
    visit admin_company_path(company)
    within('#providers_panel') do
      accept_confirm { click_link 'Delete' }
    end
    expect(page).not_to have_content('ToDelete')
  end

  context 'QSeal Certificate creation' do
    let!(:provider) { create(:provider, name: 'Acme TPP', code: 'acme_tpp', company: company, representative: user) }
    let!(:ca_cert_record) { CaRootCertificateCreator.create!(name: 'Test CA Root').first }

    scenario 'Provider show page has Create QSeal Certificate action item when no cert exists' do
      visit admin_provider_path(provider)
      expect(page).to have_link('Create QSeal Certificate')
    end

    scenario 'hides Create QSeal Certificate when an issued cert has more than 1 month until expiration' do
      QsealCertificateCreator.create!(provider: provider, ca_certificate: ca_cert_record, name: 'Long-lived Cert')
      visit admin_provider_path(provider)
      expect(page).not_to have_link('Create QSeal Certificate')
    end

    scenario 'shows Create QSeal Certificate when the issued cert expires within 1 month' do
      cert, _qseal = QsealCertificateCreator.create!(provider: provider, ca_certificate: ca_cert_record, name: 'Expiring Soon')
      cert.update_columns(not_after: 2.weeks.from_now)
      visit admin_provider_path(provider)
      expect(page).to have_link('Create QSeal Certificate')
    end

    scenario 'Provider show page has QSeal Certificates panel' do
      visit admin_provider_path(provider)
      expect(page).to have_css('#qseal_certificates_panel')
      within('#qseal_certificates_panel') do
        expect(page).to have_content('No QSeal certificates yet.')
      end
    end

    scenario 'New QSeal certificate form is pre-filled with provider name and auto-selects the only CA' do
      visit new_qseal_certificate_admin_provider_path(provider)
      expect(page).to have_content("Create a QSeal Certificate for #{provider.name}")
      expect(find_field('Name').value).to eq("#{provider.name} QSeal")
      expect(find_field('CA Certificate').value).to eq(ca_cert_record.id.to_s)
    end

    scenario 'CA Certificate option includes the CN field from the subject' do
      visit new_qseal_certificate_admin_provider_path(provider)
      expect(page).to have_select('CA Certificate', with_options: ['CN: SaltEdge CA Authority'])
    end

    scenario 'New QSeal certificate form shows all PSP role checkboxes pre-checked with full labels' do
      visit new_qseal_certificate_admin_provider_path(provider)
      QsealCertificate::PSP_ROLES.each_key do |code|
        expect(page).to have_checked_field(code, visible: :any)
        expect(page).to have_content(QsealCertificate::PSP_ROLES[code][:label])
      end
    end

    scenario 'Admin can create a QSeal certificate from the provider show page' do
      visit new_qseal_certificate_admin_provider_path(provider)
      fill_in 'Name', with: 'My QSeal Cert'
      click_button 'Create QSeal Certificate'
      expect(page).to have_content('QSeal certificate created successfully.')
      qseal = QsealCertificate.last
      expect(qseal).not_to be_nil
      expect(qseal.qc_statement_data).to match_array(QsealCertificate::PSP_ROLES.keys)
    end

    scenario 'Created QSeal certificate appears in the provider QSeal panel with TSP Name' do
      _cert, qseal = QsealCertificateCreator.create!(provider: provider, ca_certificate: ca_cert_record, name: 'Panel Cert')
      visit admin_provider_path(provider)
      within('#qseal_certificates_panel') do
        expect(page).to have_content('Panel Cert')
        expect(page).to have_content(qseal.tsp_name)
        expect(page).to have_content('TSP Name')
        expect(page).not_to have_content(qseal.certificate_record.serial_number)
      end
    end

    scenario 'Shows error when CA certificate is not found', js: true do
      visit new_qseal_certificate_admin_provider_path(provider)
      page.execute_script("document.querySelector('[name=\"ca_certificate_id\"]').removeAttribute('required'); document.querySelector('[name=\"ca_certificate_id\"]').value = '0'")
      click_button 'Create QSeal Certificate'
      expect(page).to have_content('CA Certificate not found.')
    end

    scenario 'Shows no CA certificates message when none exist', js: false do
      Certificate.where(certifiable_type: 'CaCertificate').find_each do |c|
        c.certifiable.destroy
      end
      visit new_qseal_certificate_admin_provider_path(provider)
      expect(page).to have_content("Create a QSeal Certificate for #{provider.name}")
      # The select should be present but empty
      expect(page).to have_select('CA Certificate')
    end
  end

  context 'Register TPP action item visibility' do
    let!(:provider) { create(:provider, name: 'Acme TPP', code: 'acme_tpp', company: company, representative: user) }
    let!(:ca_cert_record) { CaRootCertificateCreator.create!(name: 'Test CA Root').first }

    scenario 'is not visible without an issued QSeal certificate' do
      visit admin_provider_path(provider)
      expect(page).not_to have_link('Register TPP')
    end

    scenario 'is visible when an issued cert exists and provider is not yet registered' do
      QsealCertificateCreator.create!(provider: provider, ca_certificate: ca_cert_record, name: 'Acme QSeal')
      visit admin_provider_path(provider)
      expect(page).to have_link('Register TPP')
    end

    scenario 'is hidden when provider is already registered' do
      QsealCertificateCreator.create!(provider: provider, ca_certificate: ca_cert_record, name: 'Acme QSeal')
      provider.update!(registered_at: 1.hour.ago)
      visit admin_provider_path(provider)
      expect(page).not_to have_link('Register TPP')
    end
  end

  context 'Create Consent action' do
    let!(:provider) do
      create(:provider, name: 'Acme TPP', code: 'acme_tpp', company: company, representative: user,
                        registration_request_sent_at: 1.hour.ago)
    end

    # --- Visibility ---

    scenario 'shows Create Consent action item when registration request has been sent' do
      visit admin_provider_path(provider)
      expect(page).to have_link('Create Consent')
    end

    scenario 'does not show Create Consent action item before registration request is sent' do
      provider.update!(registration_request_sent_at: nil)
      visit admin_provider_path(provider)
      expect(page).not_to have_link('Create Consent')
    end

    scenario 'provider show page has a Consents panel with empty-state message' do
      visit admin_provider_path(provider)
      expect(page).to have_css('#consents_panel')
      within('#consents_panel') { expect(page).to have_content('No consents yet.') }
    end

    scenario 'provider show page has a TPP events panel with empty-state message' do
      visit admin_provider_path(provider)
      expect(page).to have_css('#tpp_events_panel')
      within('#tpp_events_panel') { expect(page).to have_content('No events yet.') }
    end

    # --- Behaviour: no QSeal certificate ---

    context 'when no issued QSeal certificate exists', js: true do
      scenario 'sets registered_at, shows an error alert, and records a failure event' do
        Flipper.enable(:ais_event_recording)
        expect(provider.reload.registered_at).to be_nil

        visit admin_provider_path(provider)
        accept_confirm { click_link 'Create Consent' }

        expect(page).to have_content('No issued QSeal certificate found.')
        expect(provider.reload.registered_at).to be_present

        event = Event.order(:created_at).last
        expect(event.event_type).to eq('consent_create')
        expect(event.response_body['error']).to eq('No issued QSeal certificate found')
        expect(event.provider_id).to eq(provider.id)
        expect(event.consent_id).to be_nil
      end
    end

    # --- Behaviour: with issued QSeal certificate ---

    context 'when an issued QSeal certificate exists' do
      let!(:ca_cert_record) { CaRootCertificateCreator.create!(name: 'Test CA Root').first }
      let!(:_cert) do
        QsealCertificateCreator.create!(provider: provider, ca_certificate: ca_cert_record, name: 'Acme QSeal').first
      end

      context 'when upstream consent creation succeeds', js: true do
        before { stub_create_consent(consent_id: 'con-upstream-1', consent_status: 'received') }

        scenario 'sets registered_at and shows a success notice with consent details' do
          expect(provider.reload.registered_at).to be_nil
          visit admin_provider_path(provider)
          accept_confirm { click_link 'Create Consent' }

          expect(page).to have_content('created')
          expect(page).to have_content('received')
          expect(provider.reload.registered_at).to be_present
        end

        scenario 'the new consent appears in the Consents panel' do
          visit admin_provider_path(provider)
          accept_confirm { click_link 'Create Consent' }

          within('#consents_panel') do
            expect(page).to have_content('con-upstream-1')
            expect(page).to have_content('received')
          end
        end

        scenario 'the consent_create event appears in the TPP events panel' do
          Flipper.enable(:ais_event_recording)
          visit admin_provider_path(provider)
          accept_confirm { click_link 'Create Consent' }

          within('#tpp_events_panel') do
            expect(page).to have_content('consent_create')
          end
        end
      end

      context 'when retrying after a previous upstream failure', js: true do
        let!(:existing_consent) do
          provider.consents.create!(status: Consent::STATUS_PENDING, callback_params: {})
        end

        before do
          Event.create!(provider: provider, consent: existing_consent, event_type: 'consent_create',
                        request_body: {}, request_headers: {},
                        response_body: { 'error' => 'upstream failed' }, response_headers: {},
                        occurred_at: Time.now.utc)
          stub_create_consent(consent_id: 'con-retry-1', consent_status: 'received')
        end

        scenario 'reuses the existing pending consent rather than creating a new one' do
          visit admin_provider_path(provider)
          accept_confirm { click_link 'Create Consent' }

          expect(page).to have_content("Consent #{existing_consent.id} created")
          expect(Consent.count).to eq(1)
        end
      end

      context 'when upstream consent creation fails', js: true do
        before do
          stub_request(:post, %r{priora\.saltedge\.com/artea_sandbox/api/berlingroup/v1/consents})
            .to_return(status: 400, body: '{"tppMessages":[{"text":"provider not found"}]}',
                       headers: { 'Content-Type' => 'application/json' })
        end

        scenario 'shows an error alert' do
          visit admin_provider_path(provider)
          accept_confirm { click_link 'Create Consent' }

          expect(page).to have_content('Failed to create consent: provider not found')
        end

        scenario 'records a failure event visible in the TPP events panel' do
          Flipper.enable(:ais_event_recording)
          visit admin_provider_path(provider)
          accept_confirm { click_link 'Create Consent' }

          expect(page).to have_content('Failed to create consent: provider not found')
          within('#tpp_events_panel') { expect(page).to have_content('consent_create') }
        end

        scenario 'still sets registered_at even though consent creation failed' do
          visit admin_provider_path(provider)
          accept_confirm { click_link 'Create Consent' }

          expect(page).to have_content('Failed to create consent: provider not found')
          within('.attributes_table') do
            expect(page).to have_content(Time.now.utc.strftime('%Y-%m-%d'))
          end
        end
      end
    end
  end

  context 'Fetch Accounts action' do
    let!(:provider) do
      create(:provider, name: 'Acme TPP', code: 'acme_tpp', company: company, representative: user,
                        registration_request_sent_at: 1.hour.ago, registered_at: 1.hour.ago)
    end
    let!(:ca_cert_record) { CaRootCertificateCreator.create!(name: 'Test CA Root').first }
    let!(:_cert) do
      QsealCertificateCreator.create!(provider: provider, ca_certificate: ca_cert_record, name: 'Acme QSeal').first
    end
    let!(:consent) do
      provider.consents.create!(upstream_consent_id: 'consent-valid-1', status: Consent::STATUS_VALID, callback_params: {})
    end

    scenario 'Fetch Accounts action item is visible when a valid consent exists' do
      visit admin_provider_path(provider)
      expect(page).to have_link('Fetch Accounts')
    end

    scenario 'Fetch Accounts action item is visible when only an accepted consent exists' do
      consent.update!(status: Consent::STATUS_ACCEPTED)
      visit admin_provider_path(provider)
      expect(page).to have_link('Fetch Accounts')
    end

    scenario 'Fetch Accounts action item is not visible without a valid or accepted consent' do
      consent.update!(status: Consent::STATUS_RECEIVED)
      visit admin_provider_path(provider)
      expect(page).not_to have_link('Fetch Accounts')
    end

    scenario 'new_fetch_accounts form shows eligible consents with their status and withBalance option' do
      visit new_fetch_accounts_admin_provider_path(provider)
      expect(page).to have_content("Fetch Accounts for #{provider.name}")
      expect(page).to have_select('Consent', with_options: ["Consent #{consent.id} [valid] — consent-valid-1"])
      expect(page).to have_unchecked_field(:with_balance, visible: :any)
    end

    context 'when upstream returns accounts successfully' do
      before do
        stub_accounts(
          consent_id: 'consent-valid-1',
          accounts: [
            { 'resourceId' => 'acc-001', 'iban' => 'DE89370400440532013000', 'currency' => 'EUR', 'name' => 'Checking' },
            { 'resourceId' => 'acc-002', 'iban' => 'DE00987654321', 'currency' => 'EUR', 'name' => 'Savings' }
          ]
        )
      end

      scenario 'fetches accounts and redirects to accounts index' do
        visit new_fetch_accounts_admin_provider_path(provider)
        click_button 'Fetch Accounts'

        expect(page).to have_content('Fetched 2 account(s) successfully.')
        expect(page).to have_current_path(%r{/admin/accounts})
        expect(page).to have_content('acc-001')
        expect(page).to have_content('acc-002')
      end

      scenario 'creates Account records in the DB' do
        visit new_fetch_accounts_admin_provider_path(provider)
        expect { click_button 'Fetch Accounts' }.to change(Account, :count).by(2)
      end
    end

    context 'when upstream returns an error' do
      before { stub_accounts_error(status: 403, body: { 'tppMessages' => [{ 'text' => 'CONSENT_INVALID' }] }) }

      scenario 'shows an error alert and stays on provider page' do
        visit new_fetch_accounts_admin_provider_path(provider)
        click_button 'Fetch Accounts'

        expect(page).to have_content('Failed to fetch accounts: CONSENT_INVALID')
        expect(page).to have_current_path(admin_provider_path(provider))
      end
    end

    context 'when an accepted consent is selected' do
      let!(:consent) do
        provider.consents.create!(upstream_consent_id: 'consent-accepted-1',
                                  status: Consent::STATUS_ACCEPTED, callback_params: {})
      end

      before do
        stub_accounts(
          consent_id: 'consent-accepted-1',
          accounts: [{ 'resourceId' => 'acc-001', 'iban' => 'DE89370400440532013000', 'currency' => 'EUR', 'name' => 'Checking' }]
        )
      end

      scenario 'checks status and proceeds when it has become valid' do
        stub_consent_status('consent-accepted-1', 'valid')

        visit new_fetch_accounts_admin_provider_path(provider)
        click_button 'Fetch Accounts'

        expect(page).to have_content('Fetched 1 account(s) successfully.')
        expect(consent.reload.status_before_type_cast).to eq('valid')
      end

      scenario 'shows alert and updates consent when status changed but not yet valid' do
        stub_consent_status('consent-accepted-1', 'partiallyAuthorised')

        visit new_fetch_accounts_admin_provider_path(provider)
        click_button 'Fetch Accounts'

        expect(page).to have_content("status is 'partiallyAuthorised'")
        expect(page).to have_content('authorise it first or choose a different consent')
        expect(consent.reload.status_before_type_cast).to eq('partiallyAuthorised')
      end

      scenario 'shows alert without updating consent when status is still accepted' do
        stub_consent_status('consent-accepted-1', 'accepted')

        visit new_fetch_accounts_admin_provider_path(provider)
        click_button 'Fetch Accounts'

        expect(page).to have_content("status is 'accepted'")
        expect(consent.reload.status_before_type_cast).to eq('accepted')
      end
    end
  end
end
