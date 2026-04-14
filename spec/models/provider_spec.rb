require 'rails_helper'

RSpec.describe Provider, type: :model do
  it { should have_many(:qseal_certificates) }
  it { should have_many(:certificates).through(:qseal_certificates).source(:certificate_record) }
end
