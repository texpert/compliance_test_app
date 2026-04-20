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
  action_item :new_qseal_certificate, only: :show do
    link_to 'Create QSeal Certificate', new_qseal_certificate_admin_provider_path(resource)
  end
  action_item :register_tpp, only: :show do
    if resource.certificates.where(certifiable_type: 'QsealCertificate', status: 'issued').exists?
      link_to 'Register TPP', new_tpp_registration_admin_provider_path(resource)
    end
  end
  action_item :create_consent, only: :show do
    if resource.registration_request_sent_at.present?
      link_to 'Create Consent', create_consent_admin_provider_path(resource),
              method: :post, data: { confirm: 'Create a new consent for this provider?' }
    end
  end

  member_action :new_qseal_certificate, method: :get do
    @provider = resource
    @ca_certificates = Certificate.where(certifiable_type: 'CaCertificate').order(:created_at)
    @ca_cert_options = @ca_certificates.map do |c|
      cn = c.subject.match(/CN=([^,\/]+)/)&.captures&.first&.strip
      label = [c.name, cn.present? ? "CN: #{cn}" : nil, "serial #{c.serial_number}"].compact.join(' — ')
      [label, c.id]
    end
    render 'admin/providers/new_qseal_certificate'
  end

  member_action :create_qseal_certificate, method: :post do
    provider = resource
    ca_certificate = Certificate.find_by(id: params[:ca_certificate_id])
    unless ca_certificate
      redirect_to admin_provider_path(provider), alert: 'CA Certificate not found.'
      next
    end

    roles = Array(params[:roles]).select { |r| QsealCertificate::PSP_ROLES.key?(r) }
    cert, _qseal = QsealCertificateCreator.create!(
      provider: provider,
      ca_certificate: ca_certificate,
      name: params[:name].presence || "#{provider.name} QSeal",
      roles: roles.any? ? roles : QsealCertificate::PSP_ROLES.keys
    )
    redirect_to [:admin, cert], notice: 'QSeal certificate created successfully.'
  rescue => e
    redirect_to admin_provider_path(provider), alert: "Failed to create QSeal certificate: #{e.message}"
  end

  member_action :new_tpp_registration, method: :get do
    @provider = resource
    @company = @provider.company
    @company_users = @company.users.order(:name)
    @issued_certs = @provider.certificates
                             .where(certifiable_type: 'QsealCertificate', status: 'issued')
                             .order(created_at: :desc)
    @default_representative_id = @company_users.count == 1 ? @company_users.first.id : @provider.representative_id
    render 'admin/providers/new_tpp_registration'
  end

  member_action :create_tpp_registration, method: :post do
    provider = resource
    representative = User.find_by(id: params[:representative_id])
    unless representative
      redirect_to new_tpp_registration_admin_provider_path(provider), alert: 'Representative not found.'
      next
    end

    certificate = provider.certificates.find_by(id: params[:certificate_id])

    service = SaltEdge::ProviderRegistrationService.new
    result  = service.register(provider: provider, representative: representative, certificate: certificate)

    if result.success?
      redirect_to admin_provider_path(provider),
                  notice: 'TPP registration request submitted successfully. A confirmation email will be sent to the representative.'
    else
      redirect_to admin_provider_path(provider),
                  alert: "TPP registration request failed: #{result.error.message}"
    end
  end

  member_action :create_consent, method: :post do
    provider = resource
    provider.update!(registered_at: 1.minute.ago) if provider.registered_at.nil?

    cert = provider.latest_qseal_cert
    unless cert
      Event.record(event_type: 'consent_create', provider: provider,
                   response_body: { 'error' => 'No issued QSeal certificate found' })
      redirect_to admin_provider_path(provider), alert: 'No issued QSeal certificate found.'
      next
    end

    # Reuse an existing pending consent if its last event recorded an error (retry scenario).
    pending = provider.consents.status_pending.order(:created_at).last
    last_event_errored = pending && pending.events.order(:occurred_at).last&.response_body&.key?('error')

    consent = if last_event_errored
                pending
              else
                begin
                  provider.consents.create!(status: Consent::STATUS_PENDING, callback_params: {})
                rescue => e
                  Event.record(event_type: 'consent_create', provider: provider,
                               response_body: { 'error' => "Failed to create local consent record: #{e.message}" })
                  redirect_to admin_provider_path(provider), alert: "Failed to create consent: #{e.message}"
                  next
                end
              end

    # ConsentService records the event (with full request/response headers and body) before raising.
    service = SaltEdge::ConsentService.new(certificate: cert)
    resp = service.create_and_persist_consent(consent: consent, valid_until: Date.current + 180)

    sca_note = resp['sca_redirect_url'].present? ? "SCA redirect: #{resp['sca_redirect_url']}" : 'No SCA redirect URL returned — check the Salt Edge UI for the authorisation link and open it in the browser.'
    redirect_to admin_provider_path(provider),
                notice: "Consent #{consent.id} created (status: #{resp['consent_status']}). #{sca_note}"
  rescue => e
    redirect_to admin_provider_path(provider), alert: "Failed to create consent: #{e.message}"
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
      row('Registration Request Sent') { |p| p.registration_request_sent_at&.strftime('%Y-%m-%d %H:%M UTC') || '—' }
      row('Registered At') { |p| p.registered_at&.strftime('%Y-%m-%d %H:%M UTC') || '—' }
    end

    panel 'QSeal Certificates', id: 'qseal_certificates_panel' do
      if resource.certificates.exists?
        table_for resource.certificates.includes(:certifiable).order(created_at: :desc) do
          column(:name) { |c| link_to c.name, [:admin, c] }
          column('TSP Name') { |c| c.certifiable.tsp_name }
          column :status
          column :not_before
          column :not_after
        end
      else
        div class: 'blank_slate_container' do
          span 'No QSeal certificates yet.', class: 'blank_slate'
        end
      end
    end

    columns do
      column do
        panel 'Consents', id: 'consents_panel' do
          if resource.consents.exists?
            table_for resource.consents.order(created_at: :desc) do
              column(:id)
              column(:status)
              column('Upstream ID') { |c| c.upstream_consent_id || '—' }
              column('Created') { |c| c.created_at.strftime('%Y-%m-%d %H:%M UTC') }
            end
          else
            div class: 'blank_slate_container' do
              span 'No consents yet.', class: 'blank_slate'
            end
          end
        end
      end

      column do
        panel 'TPP events', id: 'tpp_events_panel' do
          all_events = resource.events.order(occurred_at: :desc)
          if all_events.exists?
            table_for all_events do
              column('Type') { |e| e.event_type }
              column('Occurred At') { |e| e.occurred_at.strftime('%Y-%m-%d %H:%M UTC') }
              column('Response') do |e|
                status = e.response_body['status'] || e.response_body.dig('data', 'status')
                error  = e.response_body['error']
                if error
                  span error, style: 'color: #c0392b;'
                elsif status
                  span status
                else
                  span '✓ Success', style: 'color: #27ae60;'
                end
              end
            end
          else
            div class: 'blank_slate_container' do
              span 'No events yet.', class: 'blank_slate'
            end
          end
        end
      end
    end
  end
end
