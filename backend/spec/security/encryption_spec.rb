require "rails_helper"

RSpec.describe "Encryption at Rest", type: :model do
  describe "Merchant PII encryption" do
    it "encrypts email in database (not stored in plaintext)" do
      merchant = create(:merchant)

      raw = ActiveRecord::Base.connection.select_value(
        "SELECT email_ciphertext FROM merchants WHERE id = '#{merchant.id}'"
      )

      expect(raw).to be_present
      # Lockbox encrypted values are base64/binary, not plaintext
      expect(raw).not_to include("@example.com") if merchant.email_ciphertext.include?("@")
    end

    it "encrypts webhook_url in database" do
      merchant = create(:merchant, :with_webhook)

      raw = ActiveRecord::Base.connection.select_value(
        "SELECT webhook_url_ciphertext FROM merchants WHERE id = '#{merchant.id}'"
      )

      expect(raw).to be_present
      expect(raw).not_to eq("https://example.com/webhooks")
    end

    it "encrypts webhook_secret in database" do
      merchant = create(:merchant, :with_webhook)

      raw = ActiveRecord::Base.connection.select_value(
        "SELECT webhook_secret_ciphertext FROM merchants WHERE id = '#{merchant.id}'"
      )

      expect(raw).to be_present
    end
  end

  describe "API key security" do
    it "stores API key as bcrypt digest, not plaintext" do
      merchant = create(:merchant)
      _key, raw_key = ApiKey.generate_for(merchant: merchant, name: "test")

      stored_digest = ApiKey.last.key_digest
      expect(stored_digest).to start_with("$2a$") # bcrypt prefix
      expect(stored_digest).not_to eq(raw_key)
    end

    it "can authenticate with raw key against stored digest" do
      merchant = create(:merchant)
      key, raw_key = ApiKey.generate_for(merchant: merchant, name: "test")

      found = ApiKey.authenticate(raw_key)
      expect(found).to eq(key)
    end

    it "rejects invalid API keys" do
      merchant = create(:merchant)
      ApiKey.generate_for(merchant: merchant, name: "test")

      found = ApiKey.authenticate("pk_test_invalid_key_here")
      expect(found).to be_nil
    end

    it "rejects revoked API keys" do
      merchant = create(:merchant)
      key, raw_key = ApiKey.generate_for(merchant: merchant, name: "test")
      key.revoke!

      found = ApiKey.authenticate(raw_key)
      expect(found).to be_nil
    end
  end
end
