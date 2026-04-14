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

    # Add Bob to company
    select 'Bob', from: 'add_user_user_id'
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
end
