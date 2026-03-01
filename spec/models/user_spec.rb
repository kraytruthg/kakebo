require "rails_helper"

RSpec.describe User, type: :model do
  subject { build(:user) }

  it { should belong_to(:household).optional }
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:email) }
  it { should validate_uniqueness_of(:email).case_insensitive }
  it { should have_secure_password }
end
