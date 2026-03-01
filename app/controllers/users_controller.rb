class UsersController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
    if ENV["REGISTRATION_OPEN"] != "true"
      render :closed and return
    end
    @user = User.new
  end

  def create
    if ENV["REGISTRATION_OPEN"] != "true"
      render :closed, status: :forbidden and return
    end

    @user = User.new(user_params)
    if @user.save
      session[:user_id] = @user.id
      redirect_to root_path, notice: "歡迎加入！"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
