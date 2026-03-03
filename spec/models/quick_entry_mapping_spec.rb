require "rails_helper"

RSpec.describe QuickEntryMapping, type: :model do
  it { should belong_to(:household) }
  it { should belong_to(:target) }
  it { should validate_presence_of(:keyword) }

  describe "target_type validation" do
    let(:household) { create(:household) }
    let(:category) { create(:category, category_group: create(:category_group, household: household)) }

    it "allows Category target_type" do
      mapping = build(:quick_entry_mapping, household: household, target: category, keyword: "食物")
      expect(mapping).to be_valid
    end

    it "allows Account target_type" do
      account = create(:account, household: household)
      mapping = build(:quick_entry_mapping, household: household, target: account, keyword: "Jerry")
      expect(mapping).to be_valid
    end

    it "rejects invalid target_type" do
      mapping = QuickEntryMapping.new(household: household, keyword: "test", target_type: "User", target_id: 1)
      expect(mapping).not_to be_valid
      expect(mapping.errors[:target_type]).to be_present
    end
  end

  describe "keyword uniqueness" do
    let(:household) { create(:household) }
    let(:category) { create(:category, category_group: create(:category_group, household: household)) }

    it "rejects duplicate keyword within same household and target_type" do
      create(:quick_entry_mapping, household: household, target: category, keyword: "食物")
      duplicate = build(:quick_entry_mapping, household: household, target: category, keyword: "食物")
      expect(duplicate).not_to be_valid
    end

    it "allows same keyword for different target_types in same household" do
      account = create(:account, household: household)
      create(:quick_entry_mapping, household: household, target: category, keyword: "Jerry")
      mapping = build(:quick_entry_mapping, household: household, target: account, keyword: "Jerry")
      expect(mapping).to be_valid
    end

    it "allows same keyword in different households" do
      other_household = create(:household)
      other_category = create(:category, category_group: create(:category_group, household: other_household))
      create(:quick_entry_mapping, household: household, target: category, keyword: "食物")
      mapping = build(:quick_entry_mapping, household: other_household, target: other_category, keyword: "食物")
      expect(mapping).to be_valid
    end
  end
end
