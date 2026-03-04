module ApplicationHelper
  include Pagy::Frontend

  def format_amount(amount)
    number_with_delimiter(amount.to_i)
  end
end
