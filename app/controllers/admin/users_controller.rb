module Admin
  class UsersController < BaseController
    def index
      @users = User.includes(:households).order(:created_at)
    end

    def new
      @user = User.new
      @households = Household.order(:name)
    end

    def create
      @user = User.new(user_params)
      household_id = params[:household_id].presence

      User.transaction do
        if @user.save
          if household_id
            @user.household_memberships.create!(household_id: household_id, role: "member")
          end
          redirect_to admin_users_path, notice: "用戶已建立"
        else
          @households = Household.order(:name)
          render :new, status: :unprocessable_entity
          raise ActiveRecord::Rollback
        end
      end
    end

    def edit
      @user = User.find(params[:id])
      @households = Household.order(:name)
    end

    def update
      @user = User.find(params[:id])
      update_params = user_params
      update_params = update_params.except(:password, :password_confirmation) if update_params[:password].blank?
      household_id = params[:household_id].presence

      User.transaction do
        if @user.update(update_params)
          if household_id && !@user.households.exists?(id: household_id)
            @user.household_memberships.create!(household_id: household_id, role: "member")
          end
          redirect_to admin_users_path, notice: "用戶已更新"
        else
          @households = Household.order(:name)
          render :edit, status: :unprocessable_entity
          raise ActiveRecord::Rollback
        end
      end
    end

    private

    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation)
    end
  end
end
