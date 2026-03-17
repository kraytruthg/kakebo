module ApplicationHelper
  def format_amount(amount)
    number_with_delimiter(amount.to_i)
  end

  def any_transaction_filters?
    params[:account_id].present? || params[:category_id].present? || params[:date_from].present? || params[:date_to].present? || params[:query].present?
  end

  def transaction_category_label(transaction)
    if transaction.transfer?
      partner_name = transaction.transfer_pair.account.name
      if transaction.amount < 0
        tag.span("轉出 → #{partner_name}", class: "text-purple-600")
      else
        tag.span("轉入 ← #{partner_name}", class: "text-purple-600")
      end
    elsif transaction.income?
      tag.span("收入", class: "italic")
    else
      transaction.category&.name
    end
  end
end
