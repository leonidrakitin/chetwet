class SuperAdmin::PlansController < SuperAdmin::ApplicationController
  def create
    resource = new_resource(resource_params.except(:feature_list))
    resource.selected_features = raw_feature_list
    if resource.save
      redirect_to after_resource_created_path(resource), notice: translate_with_resource('create.success')
    else
      render :new, locals: { page: Administrate::Page::Form.new(dashboard, resource) }, status: :unprocessable_entity
    end
  end

  def update
    requested_resource.assign_attributes(resource_params.except(:feature_list))
    requested_resource.selected_features = raw_feature_list
    if requested_resource.save
      redirect_to after_resource_updated_path(requested_resource), notice: translate_with_resource('update.success')
    else
      render :edit, locals: { page: Administrate::Page::Form.new(dashboard, requested_resource) },
                    status: :unprocessable_entity
    end
  end

  private

  def raw_feature_list
    list = params.dig(:plan, :feature_list) || []
    list.reject(&:blank?)
  end

  def resource_params
    params.require(:plan).permit(:name, :display_name, :price, :annual_price,
                                 :trial_days, :description, :active, feature_list: [])
  end
end
