# frozen_string_literal: true

ActiveAdmin.register Certificate do
  menu label: 'Certificates'

  # Custom filter for certificate type
  filter :certifiable_type, as: :select, label: 'Type',
         collection: [['CA Root', 'CaCertificate'], %w[QSeal QsealCertificate]]
  filter :serial_number
  filter :subject
  filter :status, as: :select
  filter :created_at

  scope :all, default: true, show_count: true
  scope('CA Root') { |scope| scope.where(certifiable_type: 'CaCertificate') }
  scope('QSeal') { |scope| scope.where(certifiable_type: 'QsealCertificate') }

  index title: 'Certificates' do
    selectable_column
    id_column
    column('Type') { |c| c.certifiable_type == 'CaCertificate' ? 'CA Root' : (c.certifiable_type == 'QsealCertificate' ? 'QSeal' : c.certifiable_type) }
    column :serial_number
    column :subject
    column :status
    column :not_before
    column :not_after
    column :created_at
    actions
  end

  show title: proc { |certificate| "Certificate ##{certificate.id}" } do
    attributes_table do
      row(:id)
      row('Type') { |c| c.certifiable_type == 'CaCertificate' ? 'CA Root' : (c.certifiable_type == 'QsealCertificate' ? 'QSeal' : c.certifiable_type) }
      row :serial_number
      row :subject
      row :status
      row :not_before
      row :not_after
      row :created_at
      row :updated_at
      row :issuer do |c|
        if c.issuer
          link_to "##{c.issuer.id}", admin_certificate_path(c.issuer)
        end
      end
      row :certifiable_type
      row :certifiable_id
      row :issuer_dn
      row :public_key_hash
      row :public_key_pem
      row :pem_content
      row :csr
      row :revoked_at
      row :revocation_reason
    end
    if resource.certifiable_type == 'CaCertificate' && resource.certifiable
      panel 'CA Root Details' do
        attributes_table_for resource.certifiable do
          row :id
          row :name if resource.certifiable.respond_to?(:name)
          # Add more CA-specific fields here
        end
      end
    elsif resource.certifiable_type == 'QsealCertificate' && resource.certifiable
      panel 'QSeal Details' do
        attributes_table_for resource.certifiable do
          row :id
          row :name if resource.certifiable.respond_to?(:name)
          # Add more QSeal-specific fields here
        end
      end
    end
  end
end
