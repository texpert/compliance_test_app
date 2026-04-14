# frozen_string_literal: true

# == Schema Information
#
# Table name: ca_certificates
#
#  id                     :integer          not null, primary key
#  is_root                :boolean          default(FALSE)
#  path_length_constraint :integer
#
RSpec.describe CaCertificate, type: :model do
  it { should have_one(:certificate_record).class_name('Certificate').dependent(:destroy) }
end
