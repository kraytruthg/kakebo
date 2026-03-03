require "rails_helper"

RSpec.describe "Settings::Categories", type: :request do
  let(:user)     { create(:user) }
  let(:household) { user.household }
  let(:group)    { create(:category_group, household: household) }

  before do
    post session_path, params: { email: user.email, password: "password123" }
  end

  describe "GET /settings/category_groups/:id/categories/new" do
    it "returns 200" do
      get new_settings_category_group_category_path(group)
      expect(response).to have_http_status(:ok)
    end

    it "無法存取其他 household 的群組" do
      other_group = create(:category_group)
      expect {
        get new_settings_category_group_category_path(other_group)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST /settings/category_groups/:id/categories" do
    it "新增類別並 redirect" do
      expect {
        post settings_category_group_categories_path(group),
             params: { category: { name: "餐廳" } }
      }.to change(Category, :count).by(1)
      expect(response).to redirect_to(settings_categories_path)
    end

    it "新類別的 position 設為最大值 +1" do
      create(:category, category_group: group, position: 2)
      post settings_category_group_categories_path(group),
           params: { category: { name: "新類別" } }
      expect(Category.last.position).to eq(3)
    end

    it "名稱空白時不建立" do
      expect {
        post settings_category_group_categories_path(group),
             params: { category: { name: "" } }
      }.not_to change(Category, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /settings/category_groups/:id/categories/:id/edit" do
    it "returns 200" do
      category = create(:category, category_group: group)
      get edit_settings_category_group_category_path(group, category)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /settings/category_groups/:id/categories/:id" do
    it "更新類別名稱並 redirect" do
      category = create(:category, category_group: group, name: "舊名")
      patch settings_category_group_category_path(group, category),
            params: { category: { name: "新名" } }
      expect(category.reload.name).to eq("新名")
      expect(response).to redirect_to(settings_categories_path)
    end
  end

  describe "PATCH /settings/category_groups/:id/categories/reorder" do
    it "updates positions for categories within the group" do
      c1 = create(:category, category_group: group, position: 0)
      c2 = create(:category, category_group: group, position: 1)
      c3 = create(:category, category_group: group, position: 2)

      patch reorder_settings_category_group_categories_path(group),
            params: { positions: [ { id: c3.id, position: 0 }, { id: c1.id, position: 1 }, { id: c2.id, position: 2 } ] },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(c3.reload.position).to eq(0)
      expect(c1.reload.position).to eq(1)
      expect(c2.reload.position).to eq(2)
    end

    it "rejects reordering categories from another group" do
      other_group = create(:category_group)
      other_cat = create(:category, category_group: other_group, position: 0)

      expect {
        patch reorder_settings_category_group_categories_path(group),
              params: { positions: [ { id: other_cat.id, position: 0 } ] },
              as: :json
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "PATCH /settings/category_groups/:id/categories/:id (change group)" do
    it "moves category to another group" do
      category = create(:category, category_group: group, name: "搬家類別", position: 0)
      target_group = create(:category_group, household: household, name: "目標群組")

      patch settings_category_group_category_path(group, category),
            params: { category: { name: "搬家類別", category_group_id: target_group.id } }

      expect(category.reload.category_group).to eq(target_group)
      expect(response).to redirect_to(settings_categories_path)
    end

    it "rejects moving to a group from another household" do
      category = create(:category, category_group: group, name: "不動類別")
      other_household_group = create(:category_group)

      patch settings_category_group_category_path(group, category),
            params: { category: { name: "不動類別", category_group_id: other_household_group.id } }

      expect(category.reload.category_group).to eq(group)
    end
  end

  describe "DELETE /settings/category_groups/:id/categories/:id" do
    it "無交易時刪除成功" do
      category = create(:category, category_group: group)
      expect {
        delete settings_category_group_category_path(group, category)
      }.to change(Category, :count).by(-1)
      expect(response).to redirect_to(settings_categories_path)
    end

    it "有交易時拒絕刪除並帶 alert" do
      category = create(:category, category_group: group)
      account  = create(:account, household: household, account_type: "budget")
      create(:transaction, account: account, category: category, amount: -500, date: Date.today)
      expect {
        delete settings_category_group_category_path(group, category)
      }.not_to change(Category, :count)
      expect(response).to redirect_to(settings_categories_path)
      follow_redirect!
      expect(response.body).to include("此類別有交易記錄")
    end
  end
end
