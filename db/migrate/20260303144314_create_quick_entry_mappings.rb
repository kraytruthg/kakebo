class CreateQuickEntryMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :quick_entry_mappings do |t|
      t.references :household, null: false, foreign_key: true
      t.string :keyword, null: false
      t.string :target_type, null: false
      t.bigint :target_id, null: false
      t.timestamps
    end

    add_index :quick_entry_mappings, [ :household_id, :target_type, :keyword ], unique: true, name: "idx_quick_entry_mappings_unique_keyword"
  end
end
