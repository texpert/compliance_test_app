# == Schema Information
#
# Table name: ca_certificates
#
#  id                     :integer          not null, primary key
#  is_root                :boolean          default(FALSE)
#  path_length_constraint :integer
#
class CaCertificate < ApplicationRecord
  has_one :certificate_record, as: :certifiable, class_name: 'Certificate', dependent: :destroy
end
