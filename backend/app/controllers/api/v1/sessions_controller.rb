module Api
  module V1
    class SessionsController < Devise::SessionsController
      respond_to :json

      private

      def respond_with(resource, _opts = {})
        render json: {
          message: "Signed in successfully",
          user: {
            id: resource.id,
            email: resource.email,
            role: resource.role,
            merchant_id: resource.merchant_id
          }
        }, status: :ok
      end

      def respond_to_on_destroy
        if current_user
          render json: { message: "Signed out successfully" }, status: :ok
        else
          render json: { error: "No active session" }, status: :unauthorized
        end
      end
    end
  end
end
