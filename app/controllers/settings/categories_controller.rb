module Settings
  class CategoriesController < ApplicationController
    before_action :set_category_group

    def new
      @category = @category_group.categories.build
    end

    def create
      @category = @category_group.categories.build(category_params)
      @category.position = @category_group.categories.maximum(:position).to_i + 1
      if @category.save
        redirect_to settings_categories_path, notice: "類別已新增"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @category = @category_group.categories.find(params[:id])
    end

    def update
      @category = @category_group.categories.find(params[:id])
      if category_params[:category_group_id].present?
        target_group = Current.household.category_groups.find_by(id: category_params[:category_group_id])
        unless target_group
          redirect_to settings_categories_path, alert: "無效的目標群組"
          return
        end
      end

      if @category.update(category_params)
        if @category.saved_change_to_category_group_id?
          @category.update_column(:position, @category.category_group.categories.maximum(:position).to_i + 1)
        end
        redirect_to settings_categories_path, notice: "類別已更新"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def reorder
      positions = params.require(:positions)
      ApplicationRecord.transaction do
        positions.each do |pos|
          @category_group.categories.find(pos[:id]).update!(position: pos[:position])
        end
      end
      head :ok
    end

    def destroy
      @category = @category_group.categories.find(params[:id])
      if @category.transactions.any?
        redirect_to settings_categories_path, alert: "此類別有交易記錄，無法刪除"
      else
        @category.destroy
        redirect_to settings_categories_path, notice: "類別已刪除"
      end
    end

    private

    def set_category_group
      @category_group = Current.household.category_groups.find(params[:category_group_id])
    end

    def category_params
      params.require(:category).permit(:name, :category_group_id)
    end
  end
end
