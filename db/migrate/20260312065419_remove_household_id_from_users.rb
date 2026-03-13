class RemoveHouseholdIdFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_reference :users, :household, foreign_key: true
  end
end
