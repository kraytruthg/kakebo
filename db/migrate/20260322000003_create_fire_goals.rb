class CreateFireGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :fire_goals do |t|
      t.references :household, null: false, foreign_key: true, index: { unique: true }
      t.decimal :target_amount, precision: 14, scale: 2
      t.decimal :withdrawal_rate, precision: 5, scale: 2, null: false, default: 4.0
      t.decimal :target_annual_expense, precision: 14, scale: 2
      t.decimal :expected_return_rate, precision: 5, scale: 2, null: false, default: 7.0

      t.timestamps
    end
  end
end
