# frozen_string_literal: true

ActiveAdmin.register Company do
  permit_params :name, :email, :address, :phone_number, :zip_code, :city, :country_code

  index do
    selectable_column
    id_column
    column :name
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
      f.input :email
      f.input :address
      f.input :phone_number
      f.input :zip_code
      f.input :city
      f.input :country_code, as: :country
    end
    f.actions
  end
end
