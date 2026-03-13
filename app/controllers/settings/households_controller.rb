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

  private

  def household_params
    params.require(:household).permit(:name)
  end
end
