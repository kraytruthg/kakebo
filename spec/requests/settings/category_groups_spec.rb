require "rails_helper"

RSpec.describe "Settings::CategoryGroups", type: :request do
  let(:user) { create(:user) }
  let(:household) { user.household }

  before do
    post session_path, params: { email: user.email, password: "password123" }
  end

  describe "GET /settings/categories" do
    it "returns 200" do
      get settings_categories_path
      expect(response).to have_http_status(:ok)
    end

    it "只顯示自己 household 的群組" do
      own_group   = create(:category_group, name: "我的群組", household: household)
      other_group = create(:category_group, name: "別人群組")
      get settings_categories_path
      expect(response.body).to include("我的群組")
      expect(response.body).not_to include("別人群組")
    end
  end

  describe "GET /settings/category_groups/new" do
    it "returns 200" do
      get new_settings_category_group_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /settings/category_groups" do
    it "新增群組並 redirect" do
      expect {
        post settings_category_groups_path,
             params: { category_group: { name: "日常生活" } }
      }.to change(CategoryGroup, :count).by(1)
      expect(response).to redirect_to(settings_categories_path)
    end

    it "新群組的 position 設為最大值 +1" do
      create(:category_group, household: household, position: 3)
      post settings_category_groups_path,
           params: { category_group: { name: "新群組" } }
      expect(CategoryGroup.last.position).to eq(4)
    end

    it "名稱空白時不建立" do
      expect {
        post settings_category_groups_path,
             params: { category_group: { name: "" } }
      }.not_to change(CategoryGroup, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /settings/category_groups/:id/edit" do
    it "returns 200" do
      group = create(:category_group, household: household)
      get edit_settings_category_group_path(group)
      expect(response).to have_http_status(:ok)
    end

    it "無法存取其他 household 的群組" do
      other_group = create(:category_group)
      expect {
        get edit_settings_category_group_path(other_group)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "PATCH /settings/category_groups/:id" do
    it "更新名稱並 redirect" do
      group = create(:category_group, household: household, name: "舊名")
      patch settings_category_group_path(group),
            params: { category_group: { name: "新名" } }
      expect(group.reload.name).to eq("新名")
      expect(response).to redirect_to(settings_categories_path)
    end
  end

  describe "DELETE /settings/category_groups/:id" do
    it "無類別時刪除成功並 redirect" do
      group = create(:category_group, household: household)
      expect {
        delete settings_category_group_path(group)
      }.to change(CategoryGroup, :count).by(-1)
      expect(response).to redirect_to(settings_categories_path)
    end

    it "有類別時拒絕刪除並 redirect 帶 alert" do
      group    = create(:category_group, household: household)
      _category = create(:category, category_group: group)
      expect {
        delete settings_category_group_path(group)
      }.not_to change(CategoryGroup, :count)
      expect(response).to redirect_to(settings_categories_path)
      follow_redirect!
      expect(response.body).to include("請先刪除群組內所有類別")
    end
  end
end
