require "rails_helper"

RSpec.describe User, "#admin?" do
  it "returns true when user email is in ADMIN_EMAILS" do
    user = build(:user, email: "admin@example.com")
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("ADMIN_EMAILS", "").and_return("admin@example.com")
    expect(user.admin?).to be true
  end

  it "returns false when user email is not in ADMIN_EMAILS" do
    user = build(:user, email: "normal@example.com")
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("ADMIN_EMAILS", "").and_return("admin@example.com")
    expect(user.admin?).to be false
  end

  it "handles multiple emails separated by commas" do
    user = build(:user, email: "second@example.com")
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("ADMIN_EMAILS", "").and_return("first@example.com, second@example.com")
    expect(user.admin?).to be true
  end

  it "returns false when ADMIN_EMAILS is not set" do
    user = build(:user, email: "anyone@example.com")
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("ADMIN_EMAILS", "").and_return("")
    expect(user.admin?).to be false
  end
end
