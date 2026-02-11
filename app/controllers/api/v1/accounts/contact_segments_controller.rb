class Api::V1::Accounts::ContactSegmentsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_segment, only: [:show, :update, :destroy, :preview, :change_logs, :statistics]

  def index
    @segments = Current.account.contact_segments
  end

  def show; end

  def create
    @segment = Current.account.contact_segments.create!(
      permitted_payload.merge(created_by_id: Current.user.id)
    )
  end

  def update
    @segment.update!(permitted_payload)
  end

  def destroy
    @segment.destroy!
    head :no_content
  end

  def preview
    query = @segment ? @segment.query : params[:query]&.to_unsafe_h
    return render json: { error: 'query is required' }, status: :unprocessable_entity if query.blank?

    result = ::Contacts::NestedFilterService.new(Current.account, query).perform
    contacts = result[:contacts].limit(10)
    render json: {
      count: result[:count],
      contacts: contacts.map { |c| { id: c.id, name: c.name, email: c.email } }
    }
  end

  def preview_query
    authorize ContactSegment
    query = params[:query]&.to_unsafe_h
    return render json: { error: 'query is required' }, status: :unprocessable_entity if query.blank?

    result = ::Contacts::NestedFilterService.new(Current.account, query).perform
    contacts = result[:contacts].limit(10)
    render json: {
      count: result[:count],
      contacts: contacts.map { |c| { id: c.id, name: c.name, email: c.email } }
    }
  end

  def change_logs
    @logs = @segment.change_logs.recent.includes(:contact).page(params[:page])
  end

  def statistics
    stats = ContactSegments::StatisticsService.new(@segment).call
    render json: stats
  end

  def dashboard
    segments = Current.account.contact_segments
    stats = segments.map do |segment|
      service_stats = ContactSegments::StatisticsService.new(segment).call
      {
        id: segment.id,
        name: segment.name,
        description: segment.description,
        active: segment.active,
        triggers_enabled: segment.triggers_enabled,
        query: segment.query,
        **service_stats
      }
    end
    render json: { payload: stats }
  end

  private

  def fetch_segment
    @segment = Current.account.contact_segments.find(params[:id])
  end

  def permitted_payload
    params.require(:contact_segment).permit(
      :name,
      :description,
      :active,
      :triggers_enabled,
      query: {}
    )
  end
end
