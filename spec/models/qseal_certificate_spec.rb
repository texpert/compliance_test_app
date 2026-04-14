require 'rails_helper'

RSpec.describe QsealCertificate, type: :model do
  it { should belong_to(:provider) }
  it { should have_one(:certificate_record).class_name('Certificate').dependent(:destroy) }
end
