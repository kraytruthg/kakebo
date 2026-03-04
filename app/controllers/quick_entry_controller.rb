class QuickEntryController < ApplicationController
  def new
  end

  def create
    if params[:confirm] == "1"
      create_transaction
    else
      parse_and_resolve
    end
  end

  private

  def parse_and_resolve
    parsed = QuickEntryParser.parse(params[:input].to_s)
    if parsed.nil?
      redirect_to new_quick_entry_path, alert: "無法解析輸入，請使用格式：紀錄 {付款人} 支付 {描述} {金額}"
      return
    end

    resolved = QuickEntryResolver.resolve(parsed, Current.household)

    @accounts = Current.household.accounts.active
    @categories = Current.household.category_groups.includes(:categories)
    @account = resolved[:account]
    @category = resolved[:category]
    @memo = resolved[:memo]
    @amount = resolved[:amount].abs
    @date = resolved[:date]
    @payer_keyword = parsed[:payer]
    @description_keyword = parsed[:description]
    @account_matched = resolved[:account].present?
    @category_matched = resolved[:category].present?

    render :create, status: :unprocessable_entity
  end

  def create_transaction
    account = Current.household.accounts.find(params[:account_id])
    category = nil
    if params[:category_id].present?
      category = Category.joins(:category_group)
                         .where(category_groups: { household_id: Current.household.id })
                         .find(params[:category_id])
    end

    transaction = account.transactions.build(
      category: category,
      amount: -params[:amount].to_d.abs,
      date: params[:date],
      memo: params[:memo]
    )

    if transaction.save
      account.recalculate_balance!
      save_mappings_if_requested
      redirect_to new_quick_entry_path, notice: "交易已建立：#{params[:memo]} #{helpers.format_amount(params[:amount].to_d)}"
    else
      redirect_to new_quick_entry_path, alert: "建立失敗，請確認所有欄位"
    end
  end

  def save_mappings_if_requested
    if params[:remember_account] == "1" && params[:payer_keyword].present? && params[:account_id].present?
      Current.household.quick_entry_mappings.find_or_create_by(
        keyword: params[:payer_keyword],
        target_type: "Account"
      ) do |m|
        m.target_id = params[:account_id]
      end
    end

    if params[:remember_category] == "1" && params[:description_keyword].present? && params[:category_id].present?
      Current.household.quick_entry_mappings.find_or_create_by(
        keyword: params[:description_keyword],
        target_type: "Category"
      ) do |m|
        m.target_id = params[:category_id]
      end
    end
  end
end
