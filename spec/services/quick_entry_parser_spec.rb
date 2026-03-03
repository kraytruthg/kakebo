require "rails_helper"

RSpec.describe QuickEntryParser do
  describe ".parse" do
    it "parses full format: 紀錄 Jerry 支付 家樂福採買 100" do
      result = QuickEntryParser.parse("紀錄 Jerry 支付 家樂福採買 100")
      expect(result).to eq({ payer: "Jerry", description: "家樂福採買", amount: 100.0 })
    end

    it "parses full format with 記錄 variant" do
      result = QuickEntryParser.parse("記錄 Jerry 支付 停車費 50")
      expect(result).to eq({ payer: "Jerry", description: "停車費", amount: 50.0 })
    end

    it "parses full format with decimal amount" do
      result = QuickEntryParser.parse("紀錄 Jerry 支付 咖啡 99.5")
      expect(result).to eq({ payer: "Jerry", description: "咖啡", amount: 99.5 })
    end

    it "parses short format without verb: Jerry 停車費 100" do
      result = QuickEntryParser.parse("Jerry 停車費 100")
      expect(result).to eq({ payer: "Jerry", description: "停車費", amount: 100.0 })
    end

    it "parses minimal format: 停車費 100" do
      result = QuickEntryParser.parse("停車費 100")
      expect(result).to eq({ payer: nil, description: "停車費", amount: 100.0 })
    end

    it "parses multi-word description: 家樂福採買 2500" do
      result = QuickEntryParser.parse("家樂福採買 2500")
      expect(result).to eq({ payer: nil, description: "家樂福採買", amount: 2500.0 })
    end

    it "handles extra whitespace" do
      result = QuickEntryParser.parse("  紀錄  Jerry  支付  午餐  350  ")
      expect(result).to eq({ payer: "Jerry", description: "午餐", amount: 350.0 })
    end

    it "parses full format without spaces (voice input): 紀錄Jerry支付停車費100" do
      result = QuickEntryParser.parse("紀錄Jerry支付停車費100")
      expect(result).to eq({ payer: "Jerry", description: "停車費", amount: 100.0 })
    end

    it "parses full format with partial spaces: 紀錄Jerry 支付家樂福採買 500" do
      result = QuickEntryParser.parse("紀錄Jerry 支付家樂福採買 500")
      expect(result).to eq({ payer: "Jerry", description: "家樂福採買", amount: 500.0 })
    end

    it "parses verb format without prefix: 老婆支付家樂福採買300" do
      result = QuickEntryParser.parse("老婆支付家樂福採買300")
      expect(result).to eq({ payer: "老婆", description: "家樂福採買", amount: 300.0 })
    end

    it "parses verb format with spaces: 老婆 支付 家樂福採買 300" do
      result = QuickEntryParser.parse("老婆 支付 家樂福採買 300")
      expect(result).to eq({ payer: "老婆", description: "家樂福採買", amount: 300.0 })
    end

    it "parses minimal format without space: 停車費100" do
      result = QuickEntryParser.parse("停車費100")
      expect(result).to eq({ payer: nil, description: "停車費", amount: 100.0 })
    end

    it "returns nil for unparseable input" do
      result = QuickEntryParser.parse("hello")
      expect(result).to be_nil
    end

    it "returns nil for empty string" do
      result = QuickEntryParser.parse("")
      expect(result).to be_nil
    end
  end
end
