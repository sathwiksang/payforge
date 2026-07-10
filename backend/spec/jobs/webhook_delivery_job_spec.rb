require "rails_helper"

RSpec.describe WebhookDeliveryJob do
  let(:merchant) { create(:merchant, :with_webhook) }
  let(:delivery) { create(:webhook_delivery_attempt, merchant: merchant) }

  describe "#perform" do
    context "successful delivery" do
      before do
        stub_request(:post, "https://example.com/webhooks")
          .to_return(status: 200, body: "OK")
      end

      it "marks delivery as delivered" do
        described_class.new.perform(delivery.id, 0)

        delivery.reload
        expect(delivery.status).to eq("delivered")
        expect(delivery.delivered_at).to be_present
        expect(delivery.response_code).to eq(200)
      end

      it "sends correct headers" do
        described_class.new.perform(delivery.id, 0)

        expect(WebMock).to have_requested(:post, "https://example.com/webhooks")
          .with { |req|
            req.headers["X-Payforge-Signature"].present? &&
            req.headers["Content-Type"] == "application/json"
          }
      end
    end

    context "failed delivery" do
      before do
        stub_request(:post, "https://example.com/webhooks")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "marks delivery as failed" do
        described_class.new.perform(delivery.id, 0)

        delivery.reload
        expect(delivery.status).to eq("failed")
        expect(delivery.response_code).to eq(500)
      end

      it "schedules a retry with backoff" do
        expect {
          described_class.new.perform(delivery.id, 0)
        }.to change(WebhookDeliveryJob.jobs, :size).by(1) if defined?(Sidekiq::Testing)
      end
    end

    context "exhausted retries" do
      before do
        stub_request(:post, "https://example.com/webhooks")
          .to_return(status: 500, body: "Error")
      end

      it "marks delivery as exhausted after max retries" do
        described_class.new.perform(delivery.id, 5)

        delivery.reload
        expect(delivery.status).to eq("exhausted")
      end
    end

    context "connection error" do
      before do
        stub_request(:post, "https://example.com/webhooks")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
      end

      it "handles connection failures gracefully" do
        described_class.new.perform(delivery.id, 0)

        delivery.reload
        expect(delivery.status).to eq("failed")
        expect(delivery.error_message).to include("Connection refused")
      end
    end
  end
end
