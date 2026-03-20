class Api::V1::BaseController < ActionController::Base
  include ApiAuthenticatable

  skip_forgery_protection

  rescue_from ActiveRecord::RecordNotFound do
    render json: { status: "error", message: "Not found" }, status: :not_found
  end

  private

  def render_success(data = {})
    render json: { status: "ok" }.merge(data)
  end

  def render_error(message, status: :unprocessable_entity)
    render json: { status: "error", message: message }, status: status
  end
end
