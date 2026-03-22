class FireGoalsController < ApplicationController
  def create
    @fire_goal = Current.household.build_fire_goal(fire_goal_params)

    if @fire_goal.save
      redirect_to reports_fire_path, notice: "FIRE 目標已設定"
    else
      load_fire_data
      render "reports/fire", status: :unprocessable_entity
    end
  end

  def update
    @fire_goal = Current.household.fire_goal

    if @fire_goal.update(fire_goal_params)
      redirect_to reports_fire_path, notice: "FIRE 目標已更新"
    else
      load_fire_data
      render "reports/fire", status: :unprocessable_entity
    end
  end

  private

  def fire_goal_params
    params.require(:fire_goal).permit(
      :withdrawal_rate, :expected_return_rate,
      :target_annual_expense, :target_amount
    )
  end

  def load_fire_data
    @household = Current.household
    @net_worth_series = @household.monthly_net_worth_series
  end
end
