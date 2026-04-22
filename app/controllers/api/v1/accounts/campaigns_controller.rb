class Api::V1::Accounts::CampaignsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_campaign, only: [:show, :update, :destroy, :send_now, :preview_audience, :campaign_statistics]

  def index
    @campaigns = Current.account.campaigns.includes(:inbox, :yclients_integration).ordered
    @yclients_integrations = Current.account.yclients_integrations.active.order(:salon_id)
  end

  def show; end

  def create
    @campaign = Current.account.campaigns.create!(campaign_params)
    render :show
  end

  def update
    @campaign.update!(campaign_params)
    render :show
  end

  def destroy
    @campaign.destroy!
    head :ok
  end

  def send_now
    Campaigns::DispatchJob.perform_later(@campaign.id)
    render :show
  end

  def preview_audience
    conversations = Campaigns::AudienceScope.new(campaign: @campaign).call
    contacts = conversations.map(&:contact).uniq(&:id)
    render json: {
      count: contacts.size,
      sample: contacts.first(10).map { |c| { id: c.id, name: c.name, email: c.email, phone_number: c.phone_number } }
    }
  end

  def statistics
    period = params[:period] || '30d'
    render json: { payload: Campaigns::StatisticsService.new(Current.account, period: period).call }
  end

  def campaign_statistics
    period = params[:period] || '30d'
    render json: { payload: Campaigns::StatisticsService.new(Current.account, period: period).for_campaign(@campaign) }
  end

  private

  def fetch_campaign
    @campaign = Current.account.campaigns.find(params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(
      :name, :description, :enabled, :inbox_id, :yclients_integration_id, :scheduled_at,
      schedule: {},
      audience: { tags: [], exclude_tags: [], segment_id: nil },
      metadata: {},
      messages: [:text, { attachments: [:id, :type, :name, :url], buttons: [:id, :label, :type, :url, :templateId] }]
    )
  end
end
