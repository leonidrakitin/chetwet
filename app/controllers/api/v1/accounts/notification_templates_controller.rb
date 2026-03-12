class Api::V1::Accounts::NotificationTemplatesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_template, only: [:show, :update, :destroy, :clone]

  def index
    @notification_templates = Current.account.notification_templates.includes(:inbox, :yclients_integration).ordered
    @yclients_integrations = Current.account.yclients_integrations.active.order(:salon_id)
  end

  def show; end

  def create
    @notification_template = Current.account.notification_templates.create!(notification_template_params)
    render :show
  end

  def update
    @notification_template.update!(notification_template_params)
    render :show
  end

  def destroy
    @notification_template.destroy!
    head :ok
  end

  def clone
    cloned = @notification_template.dup
    cloned.position = Current.account.notification_templates.maximum(:position).to_i + 1
    cloned.name = "#{@notification_template.name} (copy)"
    cloned.save!
    @notification_template = cloned
    render :show
  end

  def reorder
    templates = Current.account.notification_templates.where(id: reorder_params.pluck(:id))

    ActiveRecord::Base.transaction do
      reorder_params.each do |item|
        templates.find(item[:id].to_i).update!(position: item[:position].to_i)
      end
    end

    @notification_templates = Current.account.notification_templates.includes(:inbox, :yclients_integration).ordered
    @yclients_integrations = Current.account.yclients_integrations.active.order(:salon_id)
    render :index
  end

  private

  def fetch_template
    @notification_template = Current.account.notification_templates.find(params[:id])
  end

  def notification_template_params
    params.require(:notification_template).permit(
      :name, :description, :template_type, :event_type, :enabled, :position, :inbox_id, :yclients_integration_id,
      :last_sent_at, :next_send_at,
      schedule: {},
      conditions: {},
      audience: { segment_ids: [], tags: [], exclude_tags: [] },
      limits: {},
      metadata: {},
      messages: [:text, { attachments: [:id, :type, :name, :url], buttons: [:id, :label, :type, :url, :templateId] }]
    )
  end

  def reorder_params
    params.require(:notification_templates).map do |item|
      item.permit(:id, :position)
    end
  end
end
