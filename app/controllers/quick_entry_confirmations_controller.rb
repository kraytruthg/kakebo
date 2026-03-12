class QuickEntryConfirmationsController < ApplicationController
  skip_before_action :require_login
  skip_before_action :redirect_to_onboarding_if_needed

  layout "minimal"

  before_action :load_pending_entry

  def show
    @accounts = @household.accounts.active
    @categories = @household.category_groups.includes(:categories)
    @default_account = @household.default_account
  end

  def create
    account = @household.accounts.find(params[:account_id])
    category = Category.joins(:category_group)
                       .where(category_groups: { household_id: @household.id })
                       .find(params[:category_id])

    transaction = account.transactions.build(
      category: category,
      amount: -params[:amount].to_d.abs,
      date: params[:date],
      memo: params[:memo]
    )

    if transaction.save
      account.recalculate_balance!
      save_mappings_if_requested
      Rails.cache.delete("quick_entry_confirm:#{params[:token]}")
      render :success
    else
      redirect_to quick_entry_confirm_path(token: params[:token]), alert: "建立失敗"
    end
  end

  private

  def load_pending_entry
    @data = Rails.cache.read("quick_entry_confirm:#{params[:token]}")
    unless @data
      render plain: "連結已過期或無效", status: :not_found
      return
    end
    user = User.find(@data[:user_id])
    Current.user = user
    @household = user.households.first
    @amount = @data[:amount]
    @memo = @data[:memo]
    @payer_keyword = @data[:payer]
    @description_keyword = @data[:description]
  end

  def save_mappings_if_requested
    if params[:remember_category] == "1" && params[:description_keyword].present? && params[:category_id].present?
      @household.quick_entry_mappings.find_or_create_by(
        keyword: params[:description_keyword],
        target_type: "Category"
      ) { |m| m.target_id = params[:category_id] }
    end

    if params[:remember_account] == "1" && params[:payer_keyword].present? && params[:account_id].present?
      @household.quick_entry_mappings.find_or_create_by(
        keyword: params[:payer_keyword],
        target_type: "Account"
      ) { |m| m.target_id = params[:account_id] }
    end
  end
end
