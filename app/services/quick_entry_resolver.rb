class QuickEntryResolver
  def self.resolve(parsed, household)
    account = nil
    category = nil

    if parsed[:payer].present?
      mapping = household.quick_entry_mappings.find_by(keyword: parsed[:payer], target_type: "Account")
      account = mapping&.target
    end

    if parsed[:description].present?
      mapping = household.quick_entry_mappings.find_by(keyword: parsed[:description], target_type: "Category")
      category = mapping&.target
    end

    {
      account: account,
      category: category,
      memo: parsed[:description],
      amount: -parsed[:amount].abs,
      date: Date.today
    }
  end
end
