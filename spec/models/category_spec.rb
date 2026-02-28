require "rails_helper"

RSpec.describe Category, type: :model do
  it { should belong_to(:category_group) }
  it { should have_many(:budget_entries).dependent(:destroy) }
  it { should have_many(:transactions) }
  it { should validate_presence_of(:name) }
end
