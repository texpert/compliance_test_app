# frozen_string_literal: true

RSpec.describe 'Admin Company management', type: :feature do
  scenario 'Admin can view the companies list' do
    create(:company, name: 'Acme Corp', email: 'acme@example.com')
    visit admin_companies_path
    expect(page).to have_content('Acme Corp')
    expect(page).to have_content('acme@example.com')
  end

  scenario 'Admin can create a new company' do
    visit new_admin_company_path
    fill_in 'Name', with: 'Beta Ltd'
    fill_in 'Email', with: 'beta@example.com'
    fill_in 'Address', with: '456 Side St'
    fill_in 'Phone number', with: '654321'
    fill_in 'Zip code', with: '54321'
    fill_in 'City', with: 'Gotham'
    # Select the first matching option by value to avoid ambiguity
    find('select[name="company[country_code]"] option[value="GB"]', match: :first).select_option
    click_button 'Create Company'
    expect(page).to have_content('Company was successfully created')
    expect(page).to have_content('Beta Ltd')
    expect(Company.last.country_code).to eq('GB')
  end

  scenario 'Admin can edit a company' do
    company = create(:company, name: 'EditMe', email: 'editme@example.com')
    visit edit_admin_company_path(company)
    fill_in 'Name', with: 'EditedName'
    click_button 'Update Company'
    expect(page).to have_content('Company was successfully updated')
    expect(page).to have_content('EditedName')
  end

  scenario 'Admin can delete a company', js: true do
    company = create(:company, name: 'DeleteMe', email: 'deleteme@example.com')
    visit admin_companies_path
    expect(page).to have_content('DeleteMe')
    within(:xpath, "//tr[td[contains(.,'DeleteMe')]]") do
      accept_confirm { click_link 'Delete' }
    end
    expect(page).to have_content('Company was successfully destroyed')
    expect(page).not_to have_content('DeleteMe')
  end

  scenario 'Admin can manage company users', js: true do
    company = create(:company, name: 'PanelCo', email: 'panelco@example.com')
    user1 = create(:user, name: 'Alice', email: 'alice@example.com')
    user2 = create(:user, name: 'Bob', email: 'bob@example.com')
    company.users << user1

    visit admin_company_path(company)
    expect(page).to have_content('Users')
    expect(page).to have_content('Alice')
    within('#users_panel table tbody') do
      expect(page).not_to have_selector('tr', text: 'Bob')
    end

    # Add Bob to company — click "Add User" first to reveal the form
    within('#users_panel') { click_link 'Add User' }
    # Selector should display email after name
    expect(page).to have_select('add_user_user_id', with_options: ['Bob, bob@example.com'])
    select 'Bob, bob@example.com', from: 'add_user_user_id'
    click_button 'Add User'
    expect(page).to have_selector('#users_panel table tbody')
    within('#users_panel table tbody') do
      expect(page).to have_selector('tr', text: 'Bob')
    end

    # Remove Alice from company
    within(:xpath, "//tr[td[contains(.,'Alice')]]") do
      accept_confirm { click_link 'Remove' }
    end
    within('#users_panel table tbody') do
      expect(page).not_to have_selector('tr', text: 'Alice')
    end
  end

  scenario 'User selector appears on Add User click and dismisses on Escape', js: true do
    company = create(:company, name: 'PanelCo', email: 'panelco@example.com')
    create(:user, name: 'Alice', email: 'alice@example.com')

    visit admin_company_path(company)

    expect(page).to have_css('#add_user_form', visible: false)
    within('#users_panel') { click_link 'Add User' }
    expect(page).to have_css('#add_user_form', visible: true)
    expect(page).to have_css('#show_add_user', visible: false)

    page.send_keys(:escape)

    expect(page).to have_css('#add_user_form', visible: false)
    expect(page).to have_css('#show_add_user', visible: true)
  end

  scenario 'User selector dismisses on click outside', js: true do
    company = create(:company, name: 'PanelCo', email: 'panelco@example.com')
    create(:user, name: 'Alice', email: 'alice@example.com')

    visit admin_company_path(company)

    within('#users_panel') { click_link 'Add User' }
    expect(page).to have_css('#add_user_form', visible: true)

    # Click outside the user selector (the providers panel)
    find('#providers_panel').click

    expect(page).to have_css('#add_user_form', visible: false)
    expect(page).to have_css('#show_add_user', visible: true)
  end

  scenario 'Admin can manage company providers', js: true do
    company  = create(:company, name: 'PanelCo', email: 'panelco@example.com')
    user     = create(:user, name: 'Alice', email: 'alice@example.com')
    company.users << user
    provider = create(:provider, name: 'PanelCo TPP', code: 'panelco_tpp',
                      company: company, representative: user)

    visit admin_company_path(company)

    within('#providers_panel') do
      expect(page).to have_content('Providers')
      expect(page).to have_content('PanelCo TPP')
      expect(page).to have_content('panelco_tpp')
      expect(page).to have_content('Alice')
      expect(page).to have_link('Create Provider')
      expect(page).to have_link('Edit')
      expect(page).to have_link('Delete')
    end

    # Delete provider from the panel
    within('#providers_panel') do
      accept_confirm { click_link 'Delete' }
    end
    expect(page).to have_content('Provider was successfully destroyed')
    expect(Provider.find_by(id: provider.id)).to be_nil
  end
end
