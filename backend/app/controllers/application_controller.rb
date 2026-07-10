class ApplicationController < ActionController::API
  include ActionPolicy::Controller

  authorize :user, through: :current_user
  authorize :merchant, through: :current_merchant

  rescue_from ActionDispatch::Http::Parameters::ParseError do |e|
    render json: { error: "Invalid request body: #{e.cause&.message || e.message}" }, status: :bad_request
  end

  before_action :set_paper_trail_whodunnit
  before_action :set_paper_trail_controller_info

  private

  def current_merchant
    current_user&.merchant
  end

  def set_paper_trail_controller_info
    RequestStore.store[:paper_trail_ip] = request.remote_ip
    RequestStore.store[:paper_trail_action] = "#{controller_name}##{action_name}"
  end

  def set_paper_trail_whodunnit
    PaperTrail.request.whodunnit = try(:current_user)&.id
  end
end
