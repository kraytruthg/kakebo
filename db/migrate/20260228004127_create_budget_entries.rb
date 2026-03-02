class CreateBudgetEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_entries do |t|
      t.references :category, null: false, foreign_key: true
      t.integer :year, null: false
      t.integer :month, null: false
      t.decimal :budgeted, precision: 12, scale: 2, default: "0.0", null: false
      t.decimal :carried_over, precision: 12, scale: 2, default: "0.0", null: false

      t.timestamps
    end

    add_index :budget_entries, [ :category_id, :year, :month ], unique: true
  end
end
