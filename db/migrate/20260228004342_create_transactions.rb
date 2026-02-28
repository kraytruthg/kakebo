class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :category, foreign_key: true  # nullable（income 交易 category 為 nil）
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :date, null: false
      t.string :memo
      t.integer :transfer_pair_id  # 轉帳時兩筆互相對應

      t.timestamps
    end

    add_index :transactions, :date
    add_index :transactions, :transfer_pair_id
  end
end
