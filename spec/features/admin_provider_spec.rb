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
end
