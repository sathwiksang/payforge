module Api
  module V1
    class RegistrationsController < Devise::RegistrationsController
      respond_to :json

      private

      def respond_with(resource, _opts = {})
        if resource.persisted?
          render json: {
            message: "Account created successfully",
            user: {
              id: resource.id,
              email: resource.email,
              role: resource.role
            }
          }, status: :created
        else
          render json: {
            error: "Registration failed",
            details: resource.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def sign_up_params
        params.require(:user).permit(:email, :password, :password_confirmation, :first_name, :last_name)
      end
    end
  end
end
