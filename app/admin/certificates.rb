# frozen_string_literal: true

ActiveAdmin.register Certificate do
  index title: 'Certificates', blank_slate_link: -> {
    link_to('Create a CA Root certificate', url_for([:new_ca_root_certificate, :admin, :certificates]), class: 'button')
  } do
    selectable_column
    id_column
    column('Type') { |c|
      if c.certifiable_type == 'CaCertificate'
        'CA Root'
      else
        c.certifiable_type == 'QsealCertificate' ? 'QSeal' : c.certifiable_type
      end }
    column :name
    column :serial_number
    column :subject
    column :status
    column :not_before
    column :not_after
    column :created_at
    actions
  end

  action_item :create_ca_root_certificate, only: :index do
    link_to('Create a CA Root certificate', url_for([:new_ca_root_certificate, :admin, :certificates]), class: 'button')
  end

  # Show form for CA Root name
  collection_action :new_ca_root_certificate, method: :get do
    render 'admin/certificates/new_ca_root_certificate'
  end

  # Create CA Root with submitted name
  collection_action :create_ca_root_certificate_post, method: :post do
    name = params[:name].presence || 'SaltEdge CA Root'
    cert, ca = CaRootCertificateCreator.create!(name: name)
    unless CaRootCertificateValidator.valid?(cert.pem_content)
      cert.destroy
      ca.destroy
      next redirect_to [:admin, :certificates], alert: 'CA Root certificate failed validation checks.'
    end
    redirect_to [:admin, cert], notice: 'CA Root certificate created successfully.'
  rescue => e
    redirect_to [:admin, :certificates], alert: "Failed to create CA Root certificate: #{e.message}"
  end

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

  show title: proc { |certificate| "Certificate ##{certificate.id}" } do
    attributes_table do
      row :name
      row(:id)
      row('Type') { |c|
        if c.certifiable_type == 'CaCertificate'
          'CA Root'
        else
          c.certifiable_type == 'QsealCertificate' ? 'QSeal' : c.certifiable_type
        end }
      row :serial_number
      row :subject
      row :status
      row :not_before
      row :not_after
      row :created_at
      row :updated_at
      row :name
      row :issuer do |c|
        next if c.issuer.blank?

        link_to "##{c.issuer.id}", [:admin, c.issuer]
      end
      row :certifiable_type
      row :certifiable_id
      row :issuer_dn
      row :public_key_hash
      row :public_key_pem
      row :pem_content
      unless resource.csr.blank?
        row :csr
      end
      row :revoked_at
      row :revocation_reason
    end
  end

  permit_params(
    :name, :certifiable_type, :certifiable_id, :pem_content, :private_key, :subject, :issuer_dn, :serial_number,
    :not_before, :not_after, :status, :csr, :revoked_at, :revocation_reason, :issuer_id
  )

  form do |f|
    f.semantic_errors *f.object.errors.attribute_names

    f.inputs do
      f.input :name, input_html: { value: f.object.name.to_s, autocomplete: 'off', disabled: false }
      f.input :status
      f.input :revoked_at
      f.input :revocation_reason
      # Read-only fields
      f.li "Serial Number: #{f.object.serial_number}"
      f.li "Subject: #{f.object.subject}"
      f.li "Not Before: #{f.object.not_before}"
      f.li "Not After: #{f.object.not_after}"
      f.li "Created At: #{f.object.created_at}"
      f.li "Updated At: #{f.object.updated_at}"
      f.li "Certifiable Type: #{f.object.certifiable_type}"
      f.li "Certifiable ID: #{f.object.certifiable_id}"
      f.li "Issuer DN: #{f.object.issuer_dn}"
      f.li "Public Key Hash: #{f.object.public_key_hash}"
      f.li "Public Key PEM: #{f.object.public_key_pem}"
      f.li "PEM Content: #{f.object.pem_content}"
      f.li("Issuer: ##{f.object.issuer.id}") if f.object.issuer_id.present? && f.object.issuer.present?
      f.li("CSR: #{f.object.csr}") if f.object.csr.present?
    end
    f.actions
  end
end
