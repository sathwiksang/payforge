module Payments
  module Services
    class GatewayResponse
      attr_reader :status, :authorization_code, :decline_reason, :response_code,
                  :network_transaction_id, :raw

      def initialize(faraday_response)
        @raw = faraday_response
        body = faraday_response.body
        body = body.is_a?(String) ? Oj.load(body, symbol_keys: false) : body

        @status = body["status"]
        @authorization_code = body["authorization_code"] || body["id"]
        @decline_reason = body["decline_reason"] || body["error"]
        @response_code = body["response_code"] || faraday_response.status
        @network_transaction_id = body["id"]
      end

      def success?
        @status == "approved"
      end

      def to_h
        {
          status: @status,
          authorization_code: @authorization_code,
          decline_reason: @decline_reason,
          response_code: @response_code,
          network_transaction_id: @network_transaction_id
        }
      end

      def self.circuit_open
        new(OpenStruct.new(
          body: { "status" => "error", "decline_reason" => "circuit_breaker_open", "id" => nil },
          status: 503
        ))
      end

      def self.timeout
        new(OpenStruct.new(
          body: { "status" => "error", "decline_reason" => "timeout", "id" => nil },
          status: 504
        ))
      end

      def self.network_error(message)
        new(OpenStruct.new(
          body: { "status" => "error", "decline_reason" => message, "id" => nil },
          status: 502
        ))
      end
    end
  end
end
