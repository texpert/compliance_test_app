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
    fill_in 'Country code', with: 'GB'
    click_button 'Create Company'
    expect(page).to have_content('Company was successfully created')
    expect(page).to have_content('Beta Ltd')
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
end
