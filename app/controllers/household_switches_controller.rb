class HouseholdSwitchesController < ApplicationController
  def create
    household = Current.user.households.find(params[:household_id])
    session[:current_household_id] = household.id
    redirect_to root_path
  end
end
