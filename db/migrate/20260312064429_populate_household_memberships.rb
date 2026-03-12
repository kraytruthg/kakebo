class PopulateHouseholdMemberships < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO household_memberships (user_id, household_id, role, created_at, updated_at)
      SELECT id, household_id, 'owner', NOW(), NOW()
      FROM users
      WHERE household_id IS NOT NULL
      ON CONFLICT (user_id, household_id) DO NOTHING
    SQL
  end

  def down
    execute "DELETE FROM household_memberships"
  end
end
