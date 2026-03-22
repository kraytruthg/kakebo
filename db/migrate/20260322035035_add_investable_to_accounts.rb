class AddInvestableToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :investable, :boolean, default: true, null: false
  end
end
