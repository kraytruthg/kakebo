module Admin
  class UsersController < BaseController
    def index
      @users = User.includes(:household).order(:created_at)
    end

    def new
      @user = User.new
      @households = Household.order(:name)
    end

    def create
      @user = User.new(user_params)
      if @user.save
        redirect_to admin_users_path, notice: "用戶已建立"
      else
        @households = Household.order(:name)
        render :new, status: :unprocessable_entity
      end
    end

    private

    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation, :household_id)
    end
  end
end
