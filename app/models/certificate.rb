# == Schema Information
#
# Table name: certificates
#
#  id                :integer          not null, primary key
#  certifiable_type  :string           not null
#  csr               :text
#  issuer_dn         :string
#  name              :string
#  not_after         :datetime
#  not_before        :datetime
#  pem_content       :text
#  private_key       :text
#  public_key_hash   :string
#  public_key_pem    :text
#  revocation_reason :string
#  revoked_at        :datetime
#  serial_number     :string           not null
#  status            :string           default("pending"), not null
#  subject           :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  certifiable_id    :integer          not null
#  issuer_id         :integer
#
# Indexes
#
#  index_certificates_on_certifiable_type_and_certifiable_id  (certifiable_type,certifiable_id)
#  index_certificates_on_public_key_hash                      (public_key_hash)
#  index_certificates_on_status                               (status)
#
# Foreign Keys
#
#  issuer_id  (issuer_id => certificates.id)
#
class Certificate < ApplicationRecord
  include AASM

  delegated_type :certifiable, types: %w[CaCertificate QsealCertificate], dependent: :destroy

  belongs_to :issuer, class_name: 'Certificate', optional: true

  has_many :issued_certificates, class_name: 'Certificate', foreign_key: :issuer_id

  encrypts :private_key

  aasm column: :status do
    state :pending, initial: true
    state :issued, :revoked, :expired
    event(:issue) { transitions from: :pending, to: :issued }
    event(:revoke) { transitions from: :issued, to: :revoked }
    event(:expire) { transitions from: :issued, to: :expired }
  end

  before_validation :extract_metadata, if: :pem_content_changed?

  validates :name, presence: true
  validates :subject, :serial_number, :certifiable_type, :certifiable_id, :status, presence: true

  def self.ransackable_associations(auth_object = nil)
    %w[certifiable issued_certificates issuer]
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[
      certifiable_id certifiable_type created_at id issuer_dn issuer_id not_after not_before public_key_hash
      revocation_reason revoked_at serial_number status subject updated_at
    ]
  end

  private

  def extract_metadata
    return if pem_content.blank?
    cert = OpenSSL::X509::Certificate.new(pem_content)
    self.attributes = {
      subject: cert.subject.to_s, issuer_dn: cert.issuer.to_s,
      serial_number: cert.serial.to_s, not_before: cert.not_before,
      not_after: cert.not_after, public_key_pem: cert.public_key.to_pem,
      public_key_hash: Digest::SHA256.hexdigest(cert.public_key.to_der)
    }
  end
end
