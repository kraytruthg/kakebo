class ApplicationController < ActionController::Base
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_login
  before_action :redirect_to_onboarding_if_needed

  private

  def require_login
    unless (user_id = session[:user_id]) && (Current.user = User.find_by(id: user_id))
      redirect_to new_session_path, alert: "請先登入"
      return
    end

    set_current_household
  end

  def set_current_household
    household_id = session[:current_household_id]
    Current.household = Current.user.households.find_by(id: household_id) || Current.user.households.first
    session[:current_household_id] = Current.household&.id
  end

  def redirect_to_onboarding_if_needed
    return unless current_user_needs_onboarding?
    redirect_to onboarding_path
  end

  def current_user_needs_onboarding?
    Current.user &&
      request.path == "/budget" &&
      Current.household.accounts.none?
  end
end
