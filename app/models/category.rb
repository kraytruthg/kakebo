class Category < ApplicationRecord
  belongs_to :category_group
  has_many :budget_entries, dependent: :destroy
  has_many :transactions

  validates :name, presence: true

  default_scope { order(:position) }

  delegate :household, to: :category_group
end
