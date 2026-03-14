class Settings::HouseholdsController < ApplicationController
  def new
    @household = Household.new
  end

  def create
    @household = Household.new(household_params)
    if @household.save
      Current.user.household_memberships.create!(household: @household, role: "owner")
      session[:current_household_id] = @household.id
      redirect_to root_path, notice: "帳本已建立"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @household = find_owned_household
    return unless @household

    @transaction_count = Transaction.where(account_id: @household.account_ids).count
    @budget_entry_count = BudgetEntry.joins(category: :category_group)
                                     .where(category_groups: { household_id: @household.id }).count
  end

  def destroy
    @household = find_owned_household
    return unless @household

    if Current.user.households.count <= 1
      redirect_to settings_root_path, alert: "無法刪除唯一的帳本"
      return
    end

    if params[:household_name] != @household.name
      redirect_to settings_household_path(@household), alert: "帳本名稱不正確"
      return
    end

    safe_destroy_household(@household)
    session[:current_household_id] = Current.user.households.where.not(id: @household.id).first&.id
    redirect_to settings_root_path, notice: "帳本「#{@household.name}」已刪除"
  end

  private

  def household_params
    params.require(:household).permit(:name)
  end

  def find_owned_household
    household = Current.user.households.find_by(id: params[:id])
    membership = Current.user.household_memberships.find_by(household: household)

    unless household && membership&.role == "owner"
      redirect_to settings_root_path, alert: "權限不足"
      return nil
    end

    household
  end

  def safe_destroy_household(household)
    ActiveRecord::Base.transaction do
      # Create default households for orphaned members
      other_members = household.users.where.not(id: Current.user.id)
      orphaned = other_members.select { |u| u.households.count == 1 }
      orphaned.each do |user|
        new_hh = Household.create!(name: "#{user.name} 的家")
        HouseholdMembership.create!(user: user, household: new_hh, role: "owner")
      end

      # Safe delete order to bypass model callbacks
      household.update_columns(default_account_id: nil)
      Transaction.where(account_id: household.account_ids).delete_all
      BudgetEntry.joins(category: :category_group)
                 .where(category_groups: { household_id: household.id })
                 .delete_all
      Category.where(category_group_id: household.category_group_ids).delete_all
      CategoryGroup.where(household_id: household.id).delete_all
      household.destroy!
    end
  end
end
