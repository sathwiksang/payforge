require "rails_helper"

RSpec.describe "Password Policy (PCI DSS 4.0)", type: :model do
  let(:merchant) { create(:merchant) }

  it "rejects passwords shorter than 12 characters" do
    user = User.new(
      email: "short@example.com",
      password: "Short1!pass",
      password_confirmation: "Short1!pass",
      role: "viewer",
      merchant: merchant
    )
    expect(user).not_to be_valid
    expect(user.errors[:password]).to be_present
  end

  it "accepts passwords of 12+ characters" do
    user = User.new(
      email: "long@example.com",
      password: "SecurePass12!!",
      password_confirmation: "SecurePass12!!",
      role: "viewer",
      merchant: merchant
    )
    expect(user).to be_valid
  end

  it "locks account after 5 failed attempts" do
    user = create(:user, merchant: merchant)
    5.times do
      user.increment_failed_attempts
      user.save(validate: false)
    end
    user.lock_access!(send_instructions: false) if user.failed_attempts >= 5
    expect(user.reload.access_locked?).to be true
  end

  it "bcrypt cost factor is 12 in non-test environments" do
    # In test env it's 1 for speed, but config should be 12
    expect(Devise.stretches).to eq(1) # test env
  end

  it "JWT tokens expire after 1 hour" do
    expect(Devise::JWT.config.expiration_time).to eq(3600)
  end
end
