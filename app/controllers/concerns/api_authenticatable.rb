module ApiAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_token!
  end

  private

  def authenticate_api_token!
    token = request.headers["Authorization"]&.delete_prefix("Bearer ")
    user = ApiToken.authenticate(token)
    if user
      Current.user = user
      Current.household = user.households.first
    else
      render json: { error: "Invalid or missing API token" }, status: :unauthorized
    end
  end
end
