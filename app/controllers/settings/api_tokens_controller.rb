module Settings
  class ApiTokensController < ApplicationController
    def index
      @api_tokens = Current.user.api_tokens.order(created_at: :desc)
      @accounts = Current.household.accounts.active
      @households = Current.user.households
    end

    def create
      ApiToken.generate_for(Current.user, name: "iPhone Shortcut")
      redirect_to settings_api_tokens_path, notice: "Token 已產生"
    end

    def destroy
      token = Current.user.api_tokens.find(params[:id])
      token.destroy
      redirect_to settings_api_tokens_path, notice: "Token 已撤銷"
    end

    def update_default_account
      account_id = params[:default_account_id].presence
      if account_id
        Current.household.accounts.find(account_id)
      end
      Current.user.update!(default_account_id: account_id)
      redirect_to settings_api_tokens_path, notice: "預設帳戶已更新"
    end
  end
end
