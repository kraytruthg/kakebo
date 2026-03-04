class AddDefaultAccountToHouseholds < ActiveRecord::Migration[8.1]
  def change
    add_reference :households, :default_account, foreign_key: { to_table: :accounts }
  end
end
