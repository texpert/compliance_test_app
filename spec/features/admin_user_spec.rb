# frozen_string_literal: true

RSpec.describe 'Admin User management', type: :feature do
  scenario 'Admin can view the users list' do
    create(:user, name: 'John Doe', email: 'john@example.com')
    visit admin_users_path
    expect(page).to have_content('John Doe')
    expect(page).to have_content('john@example.com')
  end

  scenario 'Admin can create a new user' do
    visit new_admin_user_path
    fill_in 'Name', with: 'Jane Smith'
    fill_in 'Email', with: 'jane@example.com'
    click_button 'Create User'
    expect(page).to have_content('User was successfully created')
    expect(page).to have_content('Jane Smith')
  end

  scenario 'Admin can edit a user' do
    user = create(:user, name: 'EditUser', email: 'edituser@example.com')
    visit edit_admin_user_path(user)
    fill_in 'Name', with: 'Edited User'
    click_button 'Update User'
    expect(page).to have_content('User was successfully updated')
    expect(page).to have_content('Edited User')
  end

  scenario 'Admin can delete a user', js: true do
    user = create(:user, name: 'DeleteUser', email: 'deleteuser@example.com')
    visit admin_users_path
    expect(page).to have_content('DeleteUser')
    within(:xpath, "//tr[td[contains(.,'DeleteUser')]]") do
      accept_confirm { click_link 'Delete' }
    end
    expect(page).to have_content('User was successfully destroyed')
    expect(page).not_to have_content('DeleteUser')
  end
end
