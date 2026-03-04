require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#format_amount" do
    it "formats positive integer with delimiter" do
      expect(helper.format_amount(5000)).to eq("5,000")
    end

    it "formats negative integer with delimiter" do
      expect(helper.format_amount(-1000)).to eq("-1,000")
    end

    it "formats zero" do
      expect(helper.format_amount(0)).to eq("0")
    end

    it "truncates decimals" do
      expect(helper.format_amount(1234.56)).to eq("1,234")
    end

    it "formats BigDecimal" do
      expect(helper.format_amount(BigDecimal("99999"))).to eq("99,999")
    end
  end
end
