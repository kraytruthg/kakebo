class BudgetEntryRecalculationJob < ApplicationJob
  queue_as :default

  def perform(category_id, from_year, from_month)
    category = Category.find(category_id)

    # 取得從指定月份開始（含）的所有 entries，按時間排序
    entries = category.budget_entries
                      .where("(year > ?) OR (year = ? AND month >= ?)", from_year, from_year, from_month)
                      .order(:year, :month)

    previous_available = previous_month_available(category, from_year, from_month)

    entries.each do |entry|
      entry.update_columns(carried_over: previous_available)
      previous_available = entry.available
    end
  end

  private

  def previous_month_available(category, year, month)
    prev_year, prev_month = month == 1 ? [year - 1, 12] : [year, month - 1]
    prev_entry = category.budget_entries.find_by(year: prev_year, month: prev_month)
    prev_entry&.available || 0
  end
end
