module Api
  module V1
    class StatusController < BaseController
      # GET /api/v1/status
      def show
        skip_verify_authorized!
        render json: {
          data: {
            status: "operational",
            version: "v1",
            environment: Rails.env,
            timestamp: Time.current.iso8601
          },
          meta: base_meta
        }
      end
    end
  end
end
