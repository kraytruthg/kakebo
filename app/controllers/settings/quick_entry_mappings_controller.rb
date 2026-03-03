module Settings
  class QuickEntryMappingsController < ApplicationController
    def index
      @mappings = Current.household.quick_entry_mappings.order(:target_type, :keyword)
      @category_mappings = @mappings.select { |m| m.target_type == "Category" }
      @account_mappings = @mappings.select { |m| m.target_type == "Account" }
    end

    def new
      @mapping = Current.household.quick_entry_mappings.build(target_type: params[:target_type] || "Category")
      load_targets
    end

    def create
      @mapping = Current.household.quick_entry_mappings.build(mapping_params)
      validate_target_ownership!
      if @mapping.save
        redirect_to settings_quick_entry_mappings_path, notice: "對應已新增"
      else
        load_targets
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @mapping = Current.household.quick_entry_mappings.find(params[:id])
      load_targets
    end

    def update
      @mapping = Current.household.quick_entry_mappings.find(params[:id])
      @mapping.assign_attributes(mapping_params)
      validate_target_ownership!
      if @mapping.save
        redirect_to settings_quick_entry_mappings_path, notice: "對應已更新"
      else
        load_targets
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @mapping = Current.household.quick_entry_mappings.find(params[:id])
      @mapping.destroy
      redirect_to settings_quick_entry_mappings_path, notice: "對應已刪除"
    end

    private

    def mapping_params
      params.require(:quick_entry_mapping).permit(:keyword, :target_type, :target_id)
    end

    def validate_target_ownership!
      case @mapping.target_type
      when "Category"
        Category.joins(:category_group)
                .where(category_groups: { household_id: Current.household.id })
                .find(@mapping.target_id)
      when "Account"
        Current.household.accounts.find(@mapping.target_id)
      end
    end

    def load_targets
      @categories = Current.household.category_groups.includes(:categories)
      @accounts = Current.household.accounts.active
    end
  end
end
