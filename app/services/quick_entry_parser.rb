class QuickEntryParser
  # Supported formats (most specific first):
  #   紀錄/記錄 {payer} 支付 {description} {amount}
  #   {payer} 支付 {description} {amount}
  #   {payer} {description} {amount}
  #   {description} {amount}
  AMOUNT_UNIT = /(?:元|塊|圓)?/
  FULL_PATTERN = /\A(?:紀錄|記錄)\s*(.+?)\s*支付\s*(.+?)\s*(\d+(?:\.\d+)?)#{AMOUNT_UNIT}\z/
  VERB_PATTERN = /\A(.+?)\s*支付\s*(.+?)\s*(\d+(?:\.\d+)?)#{AMOUNT_UNIT}\z/
  SHORT_PATTERN = /\A(\S+)\s+(.+?)\s+(\d+(?:\.\d+)?)#{AMOUNT_UNIT}\z/
  MINIMAL_PATTERN = /\A(.+?)\s*(\d+(?:\.\d+)?)#{AMOUNT_UNIT}\z/

  def self.parse(input)
    text = input.to_s.strip.gsub(/\s+/, " ")
    return nil if text.empty?

    if (match = text.match(FULL_PATTERN))
      { payer: match[1], description: match[2], amount: Float(match[3]) }
    elsif (match = text.match(VERB_PATTERN))
      { payer: match[1], description: match[2], amount: Float(match[3]) }
    elsif (match = text.match(SHORT_PATTERN))
      { payer: match[1], description: match[2], amount: Float(match[3]) }
    elsif (match = text.match(MINIMAL_PATTERN))
      { payer: nil, description: match[1], amount: Float(match[2]) }
    end
  end
end
