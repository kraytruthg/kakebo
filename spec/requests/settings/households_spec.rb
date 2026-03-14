require "rails_helper"

RSpec.describe "Settings::Households", type: :request do
  let(:user) { create(:user, password: "password123") }
  let(:other_user) { create(:user, password: "password123") }

  before do
    post session_path, params: { email: user.email, password: "password123" }
  end

  describe "DELETE /settings/households/:id" do
    context "when owner with multiple households" do
      let!(:second_household) do
        hh = Household.create!(name: "第二帳本")
        HouseholdMembership.create!(user: user, household: hh, role: "owner")
        hh
      end
      let(:target) { user.households.first }

      it "deletes household when name matches" do
        account = create(:account, household: target)
        create(:transaction, account: account, amount: -100, date: Date.today)

        expect {
          delete settings_household_path(target), params: { household_name: target.name }
        }.to change(Household, :count).by(-1)
          .and change(Account, :count).by(-1)
          .and change(Transaction, :count).by(-1)

        expect(response).to redirect_to(settings_root_path)
        follow_redirect!
        expect(response.body).to include("已刪除")
      end

      it "rejects when name does not match" do
        expect {
          delete settings_household_path(target), params: { household_name: "wrong" }
        }.not_to change(Household, :count)

        expect(response).to redirect_to(settings_household_path(target))
      end

      it "deletes household with categories that have transactions" do
        account = create(:account, household: target)
        cg = create(:category_group, household: target)
        cat = create(:category, category_group: cg)
        create(:budget_entry, category: cat, year: 2026, month: 1)
        create(:transaction, account: account, category: cat, amount: -50, date: Date.today)

        expect {
          delete settings_household_path(target), params: { household_name: target.name }
        }.to change(Household, :count).by(-1)
          .and change(CategoryGroup, :count).by(-1)
          .and change(Category, :count).by(-1)
          .and change(BudgetEntry, :count).by(-1)

        expect(response).to redirect_to(settings_root_path)
      end

      it "switches session to another household after deletion" do
        delete settings_household_path(target), params: { household_name: target.name }
        follow_redirect!

        get settings_root_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when owner with only one household" do
      it "rejects deletion" do
        household = user.households.first

        expect {
          delete settings_household_path(household), params: { household_name: household.name }
        }.not_to change(Household, :count)

        expect(response).to redirect_to(settings_root_path)
        follow_redirect!
        expect(response.body).to include("唯一")
      end
    end

    context "when member (not owner)" do
      it "rejects deletion" do
        household = user.households.first
        HouseholdMembership.create!(user: other_user, household: household, role: "member")

        delete session_path
        post session_path, params: { email: other_user.email, password: "password123" }

        second = Household.create!(name: "Other")
        HouseholdMembership.create!(user: other_user, household: second, role: "owner")

        expect {
          delete settings_household_path(household), params: { household_name: household.name }
        }.not_to change(Household, :count)

        expect(response).to redirect_to(settings_root_path)
      end
    end

    context "orphaned members" do
      it "creates default household for members who lose their last household" do
        household = user.households.first
        HouseholdMembership.create!(user: other_user, household: household, role: "member")

        other_user.household_memberships.where.not(household: household).destroy_all
        other_user.households.where.not(id: household.id).destroy_all

        second = Household.create!(name: "Keep")
        HouseholdMembership.create!(user: user, household: second, role: "owner")

        delete settings_household_path(household), params: { household_name: household.name }

        other_user.reload
        expect(other_user.households.count).to eq(1)
        new_hh = other_user.households.first
        expect(new_hh.name).to include(other_user.name)
      end
    end
  end

  describe "GET /settings/households/:id" do
    it "shows household details for owner" do
      household = user.households.first

      get settings_household_path(household)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(household.name)
    end

    it "redirects non-owner" do
      other_household = Household.create!(name: "Other")
      HouseholdMembership.create!(user: other_user, household: other_household, role: "owner")

      get settings_household_path(other_household)
      expect(response).to redirect_to(settings_root_path)
    end
  end
end
