class QuickEntryMapping < ApplicationRecord
  ALLOWED_TARGET_TYPES = %w[Category Account].freeze

  belongs_to :household
  belongs_to :target, polymorphic: true

  validates :keyword, presence: true
  validates :keyword, uniqueness: { scope: [ :household_id, :target_type ] }
  validates :target_type, inclusion: { in: ALLOWED_TARGET_TYPES }
end
