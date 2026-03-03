require "rails_helper"

RSpec.describe QuickEntryResolver do
  let(:household) { create(:household) }
  let(:category_group) { create(:category_group, household: household) }
  let(:category) { create(:category, category_group: category_group, name: "生活花費") }
  let!(:account) { create(:account, household: household, name: "Jerry 現金") }

  describe ".resolve" do
    context "with both mappings found" do
      before do
        create(:quick_entry_mapping, household: household, keyword: "家樂福採買", target: category)
        create(:quick_entry_mapping, household: household, keyword: "Jerry", target: account)
      end

      it "resolves account, category, memo, amount, and date" do
        parsed = { payer: "Jerry", description: "家樂福採買", amount: 100.0 }
        result = QuickEntryResolver.resolve(parsed, household)

        expect(result[:account]).to eq(account)
        expect(result[:category]).to eq(category)
        expect(result[:memo]).to eq("家樂福採買")
        expect(result[:amount]).to eq(-100.0)
        expect(result[:date]).to eq(Date.today)
      end
    end

    context "with no category mapping" do
      it "returns nil for category" do
        parsed = { payer: nil, description: "未知消費", amount: 200.0 }
        result = QuickEntryResolver.resolve(parsed, household)

        expect(result[:category]).to be_nil
        expect(result[:memo]).to eq("未知消費")
        expect(result[:amount]).to eq(-200.0)
      end
    end

    context "with no account mapping" do
      it "returns nil for account" do
        create(:quick_entry_mapping, household: household, keyword: "午餐", target: category)
        parsed = { payer: "Unknown", description: "午餐", amount: 150.0 }
        result = QuickEntryResolver.resolve(parsed, household)

        expect(result[:account]).to be_nil
        expect(result[:category]).to eq(category)
      end
    end

    context "with no payer" do
      it "returns nil for account when payer is nil" do
        parsed = { payer: nil, description: "午餐", amount: 50.0 }
        result = QuickEntryResolver.resolve(parsed, household)

        expect(result[:account]).to be_nil
      end
    end
  end
end
