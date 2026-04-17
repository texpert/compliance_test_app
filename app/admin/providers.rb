# frozen_string_literal: true

ActiveAdmin.register Provider do
  belongs_to :company, optional: true

  permit_params :name, :code, :representative_id

  # Remove the default "New Provider" top-bar button — creation is only via Company show page
  config.clear_action_items!
  action_item :edit, only: :show do
    link_to 'Edit Provider', edit_resource_path(resource)
  end
  action_item :delete, only: :show do
    link_to 'Delete Provider', resource_path(resource),
            method: :delete, data: { confirm: 'Are you sure?' }
  end

  controller do
    def build_new_resource
      resource = super
      company = parent
      return resource unless company

      resource.company = company
      resource.name = "#{company.name} TPP" if resource.name.blank?
      resource.code = company.name.tr(' ', '_').tr('-', '_').downcase if resource.code.blank?
      resource.representative ||= company.users.first if company.users.count == 1
      resource
    end
  end

  index blank_slate_link: -> { 'Create providers from a Company\'s page.' } do
    selectable_column
    id_column
    column :name
    column :code
    column :company
    column :representative
    actions
  end

  filter :name
  filter :code

  form do |f|
    company = f.object.company
    f.inputs do
      f.input :name
      f.input :code
      if company
        f.input :representative_id, as: :select,
                collection: company.users.map { |u| [u.name, u.id] },
                include_blank: company.users.count != 1,
                label: 'Representative'
      else
        f.input :representative
      end
    end
    f.actions
  end

  show do
    attributes_table do
      row :name
      row :code
      row :company
      row :representative
    end
  end
end
