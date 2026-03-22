class FireGoal < ApplicationRecord
  belongs_to :household

  validates :withdrawal_rate, presence: true, numericality: { greater_than: 0 }
  validates :expected_return_rate, presence: true, numericality: { greater_than: 0 }
  validates :household_id, uniqueness: true

  def annual_expense
    target_annual_expense || household.actual_annual_expense
  end

  def fire_number
    target_amount || (annual_expense / withdrawal_rate * 100)
  end

  def progress_percentage
    fn = fire_number
    return 0 if fn.zero?
    (household.investable_net_worth / fn * 100).round(1)
  end

  def projected_fire_date
    current = household.investable_net_worth.to_f
    target = fire_number.to_f
    return Date.current if current >= target

    monthly_saving = household.average_monthly_saving(6)
    monthly_rate = expected_return_rate / 12.0 / 100.0

    months = 0
    while current < target && months < 1200
      current = current * (1 + monthly_rate) + monthly_saving
      months += 1
    end

    months < 1200 ? Date.current + months.months : nil
  end
end
