module Settings
  class CategoryGroupsController < ApplicationController
    def index
      @category_groups = Current.household.category_groups.includes(:categories)
    end

    def new
      @category_group = Current.household.category_groups.build
    end

    def create
      @category_group = Current.household.category_groups.build(category_group_params)
      @category_group.position = Current.household.category_groups.maximum(:position).to_i + 1
      if @category_group.save
        redirect_to settings_categories_path, notice: "群組已新增"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @category_group = Current.household.category_groups.find(params[:id])
    end

    def update
      @category_group = Current.household.category_groups.find(params[:id])
      if @category_group.update(category_group_params)
        redirect_to settings_categories_path, notice: "群組已更新"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @category_group = Current.household.category_groups.find(params[:id])
      if @category_group.categories.any?
        redirect_to settings_categories_path, alert: "請先刪除群組內所有類別"
      else
        @category_group.destroy
        redirect_to settings_categories_path, notice: "群組已刪除"
      end
    end

    private

    def category_group_params
      params.require(:category_group).permit(:name)
    end
  end
end
