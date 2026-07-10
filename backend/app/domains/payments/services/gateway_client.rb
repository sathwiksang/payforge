module Payments
  module Services
    class GatewayClient
      class BusinessDeclineError < StandardError; end

      TIMEOUT = 5
      NETWORK_SIM_URL = ENV.fetch("PAYMENT_NETWORK_URL", "http://localhost:4200")

      def initialize(base_url: NETWORK_SIM_URL, data_store: nil)
        @base_url = base_url
        @data_store = data_store || Stoplight::DataStore::Memory.new
      end

      def authorize(amount_cents:, currency:, card_token:, merchant_id:, idempotency_key:)
        response = with_circuit_breaker do
          connection.post("/v1/authorize") do |req|
            req.body = {
              amount: amount_cents,
              currency: currency,
              card_number: card_token,
              merchant_id: merchant_id
            }
            req.headers["Idempotency-Key"] = idempotency_key
            req.options.timeout = TIMEOUT
          end
        end

        GatewayResponse.new(response)
      rescue Stoplight::Error::RedLight
        GatewayResponse.circuit_open
      rescue Faraday::TimeoutError
        GatewayResponse.timeout
      rescue Faraday::ConnectionFailed => e
        GatewayResponse.network_error(e.message)
      end

      def capture(authorization_code:, amount_cents:, idempotency_key:)
        response = with_circuit_breaker do
          connection.post("/v1/capture") do |req|
            req.body = {
              authorization_id: authorization_code,
              amount: amount_cents
            }
            req.headers["Idempotency-Key"] = idempotency_key
            req.options.timeout = TIMEOUT
          end
        end

        GatewayResponse.new(response)
      rescue Stoplight::Error::RedLight
        GatewayResponse.circuit_open
      rescue Faraday::TimeoutError
        GatewayResponse.timeout
      rescue Faraday::ConnectionFailed => e
        GatewayResponse.network_error(e.message)
      end

      def void(authorization_code:, idempotency_key:)
        response = with_circuit_breaker do
          connection.post("/v1/void") do |req|
            req.body = {
              authorization_id: authorization_code
            }
            req.headers["Idempotency-Key"] = idempotency_key
            req.options.timeout = TIMEOUT
          end
        end

        GatewayResponse.new(response)
      rescue Stoplight::Error::RedLight
        GatewayResponse.circuit_open
      rescue Faraday::TimeoutError
        GatewayResponse.timeout
      rescue Faraday::ConnectionFailed => e
        GatewayResponse.network_error(e.message)
      end

      def refund(amount_cents:, currency:, idempotency_key:)
        response = with_circuit_breaker do
          connection.post("/v1/refund") do |req|
            req.body = {
              amount: amount_cents,
              currency: currency
            }
            req.headers["Idempotency-Key"] = idempotency_key
            req.options.timeout = TIMEOUT
          end
        end

        GatewayResponse.new(response)
      rescue Stoplight::Error::RedLight
        GatewayResponse.circuit_open
      rescue Faraday::TimeoutError
        GatewayResponse.timeout
      rescue Faraday::ConnectionFailed => e
        GatewayResponse.network_error(e.message)
      end

      private

      def with_circuit_breaker(&block)
        light = Stoplight("payment_network",
          data_store: @data_store,
          threshold: 3,
          cool_off_time: 30
        )
        light.run(&block)
      end

      def connection
        @connection ||= Faraday.new(url: @base_url) do |f|
          f.request :json
          f.response :json
          f.adapter Faraday.default_adapter
        end
      end
    end
  end
end
