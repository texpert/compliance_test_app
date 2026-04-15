# frozen_string_literal: true

ActiveAdmin.register Certificate do
  menu label: 'Certificates'

  # Custom filter for certificate type
  filter :certifiable_type, as: :select, label: 'Type', collection: [['CA Root', 'CaCertificate'], %w[QSeal QsealCertificate]]
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
end
