# frozen_string_literal: true

RSpec.describe QsealCertificate, type: :model do
  it { should belong_to(:provider) }
  it { should have_one(:certificate_record).class_name('Certificate').dependent(:destroy) }
end
