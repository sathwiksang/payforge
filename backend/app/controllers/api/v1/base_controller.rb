module Api
  module V1
    class BaseController < ApplicationController
      include Pagy::Method

      before_action :set_correlation_id
      before_action :set_request_timing

      verify_authorized

      rescue_from ActionPolicy::Unauthorized, with: :render_forbidden
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

      private

      def set_correlation_id
        @correlation_id = request.headers["X-Correlation-Id"] || SecureRandom.uuid
        response.set_header("X-Correlation-Id", @correlation_id)
      end

      def set_request_timing
        @request_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def processing_time_ms
        return 0 unless @request_start
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @request_start) * 1000).round
      end

      # --- Standardized response helpers ---

      def render_success(data, status: :ok, meta: {})
        render json: {
          data: data,
          meta: base_meta.merge(meta)
        }, status: status
      end

      def render_created(data, meta: {})
        render_success(data, status: :created, meta: meta)
      end

      def render_paginated(collection, serializer_class, view: :default)
        pagy_obj, records = pagy(:offset, collection, limit: per_page)
        data = records.map { |r| serializer_class.render_as_hash(r, view: view) }

        render json: {
          data: data,
          meta: base_meta.merge(
            total_count: pagy_obj.count,
            page: pagy_obj.page,
            per_page: pagy_obj.limit,
            total_pages: pagy_obj.last
          ),
          links: pagination_links(pagy_obj)
        }
      end

      def render_error(message, status: :unprocessable_entity, code: nil, param: nil)
        body = {
          error: {
            type: error_type_for(status),
            code: code,
            message: message,
            param: param
          }.compact,
          meta: base_meta
        }
        render json: body, status: status
      end

      def render_not_found
        render_error("Resource not found", status: :not_found, code: "resource_not_found")
      end

      def render_unauthorized
        render_error("Unauthorized", status: :unauthorized, code: "unauthorized")
      end

      def render_forbidden(exception = nil)
        message = "Access denied"
        if exception&.result&.reasons&.respond_to?(:full_messages)
          message = "#{message}: #{exception.result.reasons.full_messages.join(', ')}"
        end
        render_error(message, status: :forbidden, code: "forbidden")
      end

      def render_conflict(message)
        render_error(message, status: :conflict, code: "conflict")
      end

      # --- Auth helpers ---

      def authenticate_merchant_api_key!
        api_key = request.headers["X-Api-Key"]
        return render_unauthorized unless api_key.present?

        key = ApiKey.authenticate(api_key)
        return render_unauthorized unless key

        @current_api_key = key
        @merchant = key.merchant
        key.update_column(:last_used_at, Time.current)
      end

      def set_merchant
        @merchant = current_user&.merchant
        render_error("No merchant associated", status: :forbidden, code: "no_merchant") unless @merchant
      end

      # --- Pagination helpers ---

      def per_page
        [params.fetch(:per_page, 25).to_i, 100].min
      end

      def pagination_links(pagy_obj)
        links = { self: request.path + "?page=#{pagy_obj.page}" }
        links[:next] = request.path + "?page=#{pagy_obj.next}" if pagy_obj.next
        links[:prev] = request.path + "?page=#{pagy_obj.previous}" if pagy_obj.previous
        links[:last] = request.path + "?page=#{pagy_obj.last}"
        links
      end

      def base_meta
        {
          request_id: @correlation_id,
          processing_time_ms: processing_time_ms
        }
      end

      def error_type_for(status)
        case status
        when :not_found then "not_found"
        when :unauthorized then "authentication_error"
        when :forbidden then "authorization_error"
        when :unprocessable_entity then "validation_error"
        when :conflict then "conflict_error"
        when :too_many_requests then "rate_limit_error"
        else "api_error"
        end
      end
    end
  end
end
