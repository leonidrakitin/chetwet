class Api::V1::Accounts::NotificationTemplatesController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_template, only: [:show, :update, :destroy, :clone, :send_now, :preview_audience]

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

  DELIVERY_LIMITS_DEFAULTS = {
    'max_per_day' => 3,
    'stop_if_replied' => true,
    'skip_if_has_active_dialog' => true,
    'stop_if_replied_retry_minutes' => 60,
    'per_contact_gap_minutes' => 30,
    'quiet_hours_from' => '22:00',
    'quiet_hours_to' => '08:00'
  }.freeze

  def cascade_settings
    render json: { payload: (Current.account.cascade_settings || { 'marketing' => [], 'service' => [] }) }
  end

  def update_cascade_settings
    Current.account.update!(cascade_settings: cascade_settings_params.to_h)
    render json: { payload: Current.account.cascade_settings }
  end

  def delivery_limits
    render json: { payload: DELIVERY_LIMITS_DEFAULTS.merge(Current.account.notification_delivery_limits || {}) }
  end

  def update_delivery_limits
    Current.account.update!(notification_delivery_limits: delivery_limits_params.to_h)
    render json: { payload: DELIVERY_LIMITS_DEFAULTS.merge(Current.account.notification_delivery_limits || {}) }
  end

  def send_now
    NotificationTemplates::DispatchJob.perform_later(@notification_template)
    render :show
  end

  def preview_audience
    conversations = NotificationTemplates::AudienceScope.new(template: @notification_template).call
    contacts = conversations.map(&:contact).uniq(&:id)
    render json: {
      count: contacts.size,
      sample: contacts.first(10).map { |c| { id: c.id, name: c.name, email: c.email, phone_number: c.phone_number } }
    }
  end

  def statistics
    raw = Current.account.notification_template_deliveries
                 .group(:notification_template_id, :status)
                 .count

    stats = {}
    raw.each do |(template_id, status), count|
      stats[template_id] ||= { sent: 0, failed: 0, skipped: 0, replied: 0, total: 0 }
      stats[template_id][status.to_sym] = count
      stats[template_id][:total] += count
    end

    render json: { payload: stats }
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
      audience: { tags: [], exclude_tags: [], segment_ids: [], segment_match_mode: nil, require_mailing_consent: nil },
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

  def cascade_settings_params
    params.require(:cascade_settings).permit(marketing: [], service: [])
  end

  def delivery_limits_params
    params.require(:notification_delivery_limits).permit(
      :max_per_day, :stop_if_replied, :skip_if_has_active_dialog,
      :stop_if_replied_retry_minutes, :per_contact_gap_minutes,
      :quiet_hours_from, :quiet_hours_to
    )
  end
end
