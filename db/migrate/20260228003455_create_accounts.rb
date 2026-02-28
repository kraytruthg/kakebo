class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.references :household, null: false, foreign_key: true
      t.string :name, null: false
      t.string :account_type, null: false
      t.decimal :starting_balance, precision: 12, scale: 2, default: "0.0", null: false
      t.decimal :balance, precision: 12, scale: 2, default: "0.0", null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end
  end
end
