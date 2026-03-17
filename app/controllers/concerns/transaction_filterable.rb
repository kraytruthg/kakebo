module TransactionFilterable
  extend ActiveSupport::Concern

  private

  def apply_transaction_filters(scope)
    scope = scope.where(account_id: params[:account_id]) if params[:account_id].present?

    if params[:category_id] == "income"
      scope = scope.where(category_id: nil).where(transfer_pair_id: nil)
    elsif params[:category_id].present?
      scope = scope.where(category_id: params[:category_id])
    end

    scope = scope.where("date >= ?", params[:date_from]) if params[:date_from].present?
    scope = scope.where("date <= ?", params[:date_to]) if params[:date_to].present?

    if params[:query].present?
      sanitized = ActiveRecord::Base.sanitize_sql_like(params[:query])
      scope = scope.where("memo ILIKE ?", "%#{sanitized}%")
    end

    scope
  end
end
