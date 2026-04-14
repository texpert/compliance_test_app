# frozen_string_literal: true

RSpec.describe CaCertificate, type: :model do
  it { should have_one(:certificate_record).class_name('Certificate').dependent(:destroy) }
end
