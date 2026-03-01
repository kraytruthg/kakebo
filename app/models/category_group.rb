class CategoryGroup < ApplicationRecord
  belongs_to :household
  has_many :categories, -> { order(:position) }, dependent: :destroy

  validates :name, presence: true

  default_scope { order(:position) }

  before_destroy :prevent_if_has_categories

  private

  def prevent_if_has_categories
    if categories.any?
      errors.add(:base, "請先移除此群組內的所有類別")
      throw :abort
    end
  end
end
