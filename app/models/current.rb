class Current < ActiveSupport::CurrentAttributes
  attribute :user

  delegate :household, to: :user, allow_nil: true
end
