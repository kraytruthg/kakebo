class SessionsController < ApplicationController
  skip_before_action :require_login

  def new
  end

  def create
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      reset_session
      session[:user_id] = user.id
      session[:current_household_id] = user.households.first&.id
      redirect_to root_path, notice: "歡迎回來，#{user.name}！"
    else
      redirect_to new_session_path, alert: "Email 或密碼錯誤"
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to new_session_path
  end
end
