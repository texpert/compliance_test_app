# frozen_string_literal: true

ActiveAdmin.register Company do
  permit_params :name, :official_name, :email, :address, :phone_number, :zip_code, :city, :country_code

  index do
    selectable_column
    id_column
    column :name
    column :official_name
    column :email
    column :address
    column :phone_number
    column :zip_code
    column :city
    column :country_code
    actions
  end

  filter :name
  filter :email
  filter :city
  filter :country_code

  form do |f|
    f.inputs do
      f.input :name
      f.input :official_name
      f.input :email
      f.input :address
      f.input :phone_number
      f.input :zip_code
      f.input :city
      f.input :country_code, as: :country
    end
    f.actions
  end

  show do
    attributes_table do
      row :name
      row :official_name
      row :email
      row :address
      row :phone_number
      row :zip_code
      row :city
      row :country_code
    end

    div id: 'users_panel' do
      render partial: 'admin/companies/users_panel', locals: { company: company }
    end
  end

  member_action :remove_user, method: :post do
    company = Company.find(params[:id])
    user = User.find(params[:user_id])
    company.users.destroy(user)
    respond_to do |format|
      format.js {
        rendered = render_to_string(partial: 'admin/companies/users_panel', locals: { company: company })
        render js: "$('#users_panel').html(#{rendered.to_json});"
      }
      format.html { redirect_to resource_path(company), notice: 'User was removed from company.' }
    end
  end

  member_action :add_user, method: :post do
    company = Company.find(params[:id])
    user_id = params[:user_id] || (params[:add_user] && params[:add_user][:user_id])
    user = User.find_by(id: user_id)
    if user && !company.users.include?(user)
      company.users << user
      respond_to do |format|
        format.js {
          rendered = render_to_string(partial: 'admin/companies/users_panel', locals: { company: company })
          render js: "$('#users_panel').html(#{rendered.to_json});"
        }
        format.html { redirect_to resource_path(company), notice: 'User was added to company.' }
      end
    else
      respond_to do |format|
        format.js {
          rendered = render_to_string(partial: 'admin/companies/users_panel', locals: { company: company, error: 'User not found or already a member.' })
          render js: "$('#users_panel').html(#{rendered.to_json});"
        }
        format.html { redirect_to resource_path(company), alert: 'User not found or already a member.' }
      end
    end
  end
end
