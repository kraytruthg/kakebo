class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_login

  private

  def require_login
    unless (user_id = session[:user_id]) && (Current.user = User.find_by(id: user_id))
      redirect_to new_session_path, alert: "請先登入"
    end
  end
end
