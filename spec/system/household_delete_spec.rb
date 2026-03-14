require "rails_helper"

RSpec.describe "Household deletion", type: :system do
  before do
    driven_by :selenium, using: :headless_chrome
  end

  let(:user) { create(:user, password: "password123") }

  describe "desktop" do
    context "with multiple households" do
      let!(:second_household) do
        hh = Household.create!(name: "第二帳本")
        HouseholdMembership.create!(user: user, household: hh, role: "owner")
        hh
      end

      it "deletes household after typing name confirmation" do
        target = user.households.first
        account = create(:account, household: target)
        create(:transaction, account: account, amount: -100, date: Date.today)

        sign_in user
        visit settings_root_path
        click_link "管理帳本"

        expect(page).to have_text(target.name)
        expect(page).to have_text("帳戶數")
        expect(page).to have_button("永久刪除此帳本", disabled: true)

        fill_in "household_name", with: target.name
        expect(page).to have_button("永久刪除此帳本", disabled: false)

        click_button "永久刪除此帳本"

        expect(page).to have_text("已刪除")
        expect(page).to have_current_path(settings_root_path)
        expect(Household.find_by(id: target.id)).to be_nil
      end

      it "keeps delete button disabled when name does not match" do
        target = user.households.first
        sign_in user
        visit settings_household_path(target)

        fill_in "household_name", with: "wrong name"
        expect(page).to have_button("永久刪除此帳本", disabled: true)
      end
    end

    context "with only one household" do
      it "shows cannot-delete message" do
        sign_in user
        visit settings_root_path
        click_link "管理帳本"

        expect(page).to have_text("唯一的帳本，無法刪除")
        expect(page).not_to have_button("永久刪除此帳本")
      end
    end
  end

  describe "mobile" do
    context "with multiple households" do
      let!(:second_household) do
        hh = Household.create!(name: "第二帳本")
        HouseholdMembership.create!(user: user, household: hh, role: "owner")
        hh
      end

      it "deletes household from mobile settings" do
        target = user.households.first
        sign_in user
        page.driver.browser.manage.window.resize_to(375, 812)

        visit settings_root_path
        click_link "管理帳本"

        expect(page).to have_text(target.name)

        fill_in "household_name", with: target.name
        click_button "永久刪除此帳本"

        expect(page).to have_text("已刪除")
      end
    end

    context "with only one household" do
      it "shows cannot-delete message on mobile" do
        sign_in user
        page.driver.browser.manage.window.resize_to(375, 812)

        visit settings_root_path
        click_link "管理帳本"

        expect(page).to have_text("唯一的帳本，無法刪除")
      end
    end
  end
end
