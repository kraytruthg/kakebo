class CategoryGroup < ApplicationRecord
  belongs_to :household
  has_many :categories, -> { order(:position) }, dependent: :destroy

  validates :name, presence: true

  default_scope { order(:position) }
end
