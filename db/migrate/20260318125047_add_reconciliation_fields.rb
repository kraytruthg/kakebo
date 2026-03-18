class AddReconciliationFields < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :status, :string, null: false, default: "uncleared"
    add_column :accounts, :reconciled_balance, :decimal, precision: 12, scale: 2, default: "0.0", null: false
    add_column :accounts, :last_reconciled_at, :datetime

    add_index :transactions, :status

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE accounts SET reconciled_balance = starting_balance
        SQL
      end
    end
  end
end
