class MoveDefaultAccountFromHouseholdsToUsers < ActiveRecord::Migration[8.1]
  def up
    add_reference :users, :default_account, foreign_key: { to_table: :accounts }

    execute <<~SQL
      UPDATE users
      SET default_account_id = households.default_account_id
      FROM household_memberships
      JOIN households ON households.id = household_memberships.household_id
      WHERE household_memberships.user_id = users.id
        AND households.default_account_id IS NOT NULL
    SQL

    remove_foreign_key :households, column: :default_account_id
    remove_column :households, :default_account_id
  end

  def down
    add_reference :households, :default_account, foreign_key: { to_table: :accounts }

    execute <<~SQL
      UPDATE households
      SET default_account_id = subquery.default_account_id
      FROM (
        SELECT DISTINCT ON (household_memberships.household_id)
               household_memberships.household_id,
               users.default_account_id
        FROM users
        JOIN household_memberships ON household_memberships.user_id = users.id
        WHERE users.default_account_id IS NOT NULL
        ORDER BY household_memberships.household_id, users.id
      ) AS subquery
      WHERE households.id = subquery.household_id
    SQL

    remove_foreign_key :users, column: :default_account_id
    remove_column :users, :default_account_id
  end
end
