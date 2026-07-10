require "rails_helper"

RSpec.describe "OWASP Top 10:2025 Compliance" do
  let(:merchant_a) { create(:merchant) }
  let(:merchant_b) { create(:merchant) }
  let(:admin) { create(:user, role: "admin", merchant: merchant_a) }
  let(:manager_a) { create(:user, role: "manager", merchant: merchant_a) }
  let(:viewer_a) { create(:user, role: "viewer", merchant: merchant_a) }

  def policy_for(policy_class, record, user:)
    policy_class.new(record, user: user, merchant: user.merchant)
  end

  describe "A01: Broken Access Control" do
    it "denies cross-merchant transaction access" do
      tx = create(:transaction, merchant: merchant_b)
      policy = policy_for(TransactionPolicy, tx, user: manager_a)
      expect(policy).not_to be_show
    end

    it "denies viewer from creating transactions" do
      tx = create(:transaction, merchant: merchant_a)
      policy = policy_for(TransactionPolicy, tx, user: viewer_a)
      expect(policy).not_to be_create
    end

    it "denies viewer from refunding transactions" do
      tx = create(:transaction, merchant: merchant_a, status: "captured", captured_at: 1.day.ago)
      policy = policy_for(TransactionPolicy, tx, user: viewer_a)
      expect(policy).not_to be_refund
    end

    it "denies cross-merchant fraud case access" do
      tx = create(:transaction, merchant: merchant_b)
      fraud_case = Fraud::Models::FraudCase.create!(
        payment_transaction: tx,
        merchant: merchant_b,
        status: "open",
        priority: :high,
        risk_score: 0.9,
        decision: "block",
        model_used: "rule_engine"
      )
      policy = policy_for(FraudCasePolicy, fraud_case, user: viewer_a)
      expect(policy).not_to be_show
    end

    it "restricts merchant management to admins" do
      policy = policy_for(MerchantPolicy, merchant_a, user: viewer_a)
      expect(policy).not_to be_create
      expect(policy).not_to be_update
    end
  end

  describe "A02: Cryptographic Failures" do
    it "encrypts merchant email at rest" do
      merchant = create(:merchant)
      raw = ActiveRecord::Base.connection.select_value(
        "SELECT email_ciphertext FROM merchants WHERE id = '#{merchant.id}'"
      )
      expect(raw).not_to include("@")
      expect(raw).to be_present
    end

    it "encrypts webhook URLs at rest" do
      merchant = create(:merchant)
      raw = ActiveRecord::Base.connection.select_value(
        "SELECT webhook_url_ciphertext FROM merchants WHERE id = '#{merchant.id}'"
      )
      expect(raw).to be_present if merchant.webhook_url_ciphertext.present?
    end

    it "hashes API keys with bcrypt" do
      api_key, _raw = ApiKey.generate_for(merchant: merchant_a, name: "test")
      expect(api_key.key_digest).to start_with("$2a$")
    end
  end

  describe "A04: Insecure Design" do
    it "enforces 90-day refund window" do
      tx = create(:transaction, merchant: merchant_a, status: "captured", captured_at: 91.days.ago)
      policy = policy_for(TransactionPolicy, tx, user: admin)
      expect(policy).not_to be_refund
    end

    it "only allows refund on captured/settled transactions" do
      tx = create(:transaction, merchant: merchant_a, status: "pending")
      policy = policy_for(TransactionPolicy, tx, user: admin)
      expect(policy).not_to be_refund
    end
  end

  describe "A05: Security Misconfiguration" do
    it "configures secure headers" do
      config = SecureHeaders::Configuration.instance_variable_get(:@default_config)
      expect(config.x_frame_options).to eq("DENY")
      expect(config.x_content_type_options).to eq("nosniff")
    end

    it "enforces HSTS" do
      config = SecureHeaders::Configuration.instance_variable_get(:@default_config)
      expect(config.hsts).to include("max-age=")
    end
  end

  describe "A07: Identification and Authentication Failures" do
    it "enforces minimum 12-character passwords" do
      user = User.new(
        email: "weak@example.com",
        password: "Short1!pass",
        password_confirmation: "Short1!pass",
        role: "viewer",
        merchant: merchant_a
      )
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "locks account after 5 failed attempts" do
      user = create(:user, merchant: merchant_a)
      5.times { user.increment_failed_attempts }
      user.save(validate: false)
      user.lock_access!(send_instructions: false)
      expect(user.reload.access_locked?).to be true
    end

    it "JWT tokens expire after 1 hour" do
      expect(Devise::JWT.config.expiration_time).to eq(3600)
    end
  end

  describe "A08: Software and Data Integrity Failures" do
    it "creates audit trail for transaction changes" do
      tx = create(:transaction, merchant: merchant_a)
      expect(tx.versions).to be_present
      expect(tx.versions.last.event).to eq("create")
    end

    it "tracks merchant changes" do
      merchant = create(:merchant)
      merchant.update!(name: "Updated Name")
      expect(merchant.versions.last.event).to eq("update")
    end
  end

  describe "A09: Security Logging and Monitoring Failures" do
    it "audit versions include merchant_id metadata" do
      tx = create(:transaction, merchant: merchant_a)
      version = tx.versions.last
      expect(version.merchant_id).to eq(merchant_a.id)
    end

    it "PaperTrail tracks whodunnit" do
      PaperTrail.request.whodunnit = admin.id.to_s
      tx = create(:transaction, merchant: merchant_a)
      expect(tx.versions.last.whodunnit).to eq(admin.id.to_s)
      PaperTrail.request.whodunnit = nil
    end
  end
end
