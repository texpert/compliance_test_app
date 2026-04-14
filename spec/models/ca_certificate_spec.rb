require 'rails_helper'

RSpec.describe CaCertificate, type: :model do
  it { should have_one(:certificate_record).class_name('Certificate').dependent(:destroy) }
end
