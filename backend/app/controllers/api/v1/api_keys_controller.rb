module Api
  module V1
    class ApiKeysController < BaseController
      before_action :authenticate_user!
      before_action :set_merchant

      # GET /api/v1/api_keys
      def index
        skip_verify_authorized!
        keys = @merchant.api_keys.order(created_at: :desc)
        render_success(keys.map { |k| ApiKeyBlueprint.render_as_hash(k) })
      end

      # POST /api/v1/api_keys
      def create
        skip_verify_authorized!
        key, raw_key = ApiKey.generate_for(
          merchant: @merchant,
          name: params[:name] || "Untitled Key",
          environment: params[:environment] || "test"
        )

        render_created(
          ApiKeyBlueprint.render_as_hash(key).merge(secret_key: raw_key),
          meta: { warning: "Store this key securely. It cannot be shown again." }
        )
      end

      # DELETE /api/v1/api_keys/:id
      def destroy
        skip_verify_authorized!
        key = @merchant.api_keys.find(params[:id])
        key.revoke!
        render_success(ApiKeyBlueprint.render_as_hash(key.reload))
      end

      # POST /api/v1/api_keys/:id/rotate
      def rotate
        skip_verify_authorized!
        old_key = @merchant.api_keys.find(params[:id])
        old_key.revoke!

        new_key, raw_key = ApiKey.generate_for(
          merchant: @merchant,
          name: old_key.name,
          environment: old_key.environment
        )

        render_created(
          ApiKeyBlueprint.render_as_hash(new_key).merge(secret_key: raw_key),
          meta: {
            rotated_from: old_key.id,
            warning: "Store this key securely. The old key has been revoked."
          }
        )
      end

      private

      def set_merchant
        @merchant = current_user.merchant
        render_error("No merchant associated", status: :forbidden, code: "no_merchant") unless @merchant
      end
    end
  end
end
