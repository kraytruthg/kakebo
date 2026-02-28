class BudgetEntryRecalculationJob < ApplicationJob
  queue_as :default

  def perform(category_id, from_year, from_month)
    # Implemented in Task 8
  end
end
