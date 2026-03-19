class Api::V1::Accounts::SuggestionsController < Api::V1::Accounts::BaseController
  before_action :suggestion, only: [:show, :update, :destroy, :vote, :add_tag, :remove_tag]
  before_action :ensure_suggestion_owner!, only: [:update]

  def index
    suggestions = Current.account.suggestions
    suggestions = suggestions.for_user(current_user.id) if params[:scope] == 'mine'
    suggestions = suggestions
                  .search_by(params[:query])
                  .by_status(params[:status])

    suggestions = if params[:sort] == 'latest'
                    suggestions.order(created_at: :desc)
                  else
                    suggestions.ordered_by_votes
                  end

    @suggestions = suggestions.includes(:user, images_attachments: :blob)
    @current_user_votes = SuggestionVote.where(suggestion_id: @suggestions.map(&:id), user_id: current_user.id)
                                        .index_by(&:suggestion_id)
  end

  def show; end

  def create
    blob_ids = blob_signed_ids_param(suggestion_create_params)
    attrs = suggestion_create_params.except(:image_blob_signed_ids)

    @suggestion = Current.account.suggestions.build(attrs.merge(user: current_user))

    ActiveRecord::Base.transaction do
      attach_suggestion_images!(@suggestion, blob_ids)
      @suggestion.save!
    end
    @suggestion.reload
  end

  def update
    blob_ids = blob_signed_ids_param(suggestion_update_params)
    remove_ids = remove_attachment_ids_param(suggestion_update_params)
    attrs = suggestion_update_params.except(:image_blob_signed_ids, :remove_attachment_ids)

    ActiveRecord::Base.transaction do
      purge_suggestion_attachments!(@suggestion, remove_ids)
      @suggestion.assign_attributes(attrs)
      attach_suggestion_images!(@suggestion, blob_ids)
      @suggestion.save!
    end
    @suggestion.reload
  end

  def destroy
    unless @suggestion.user_id == current_user.id
      render json: { error: 'forbidden' }, status: :forbidden
      return
    end

    @suggestion.destroy!
    head :ok
  end

  def vote
    vote_type = params[:vote_type]
    @vote = @suggestion.vote_by(current_user, vote_type)
    @suggestion.reload
  end

  def add_tag
    @suggestion.add_tag(params[:tag])
  end

  def remove_tag
    @suggestion.remove_tag(params[:tag])
  end

  private

  def ensure_suggestion_owner!
    return if @suggestion.user_id == current_user.id

    render json: { error: 'forbidden' }, status: :forbidden
  end

  def suggestion
    @suggestion ||= Current.account.suggestions.includes(images_attachments: :blob).find(params[:id])
  end

  def suggestion_create_params
    params.require(:suggestion).permit(:title, :description, image_blob_signed_ids: [])
  end

  def suggestion_update_params
    params.require(:suggestion).permit(:title, :description, image_blob_signed_ids: [], remove_attachment_ids: [])
  end

  def blob_signed_ids_param(permitted)
    Array.wrap(permitted[:image_blob_signed_ids]).compact_blank
  end

  def remove_attachment_ids_param(permitted)
    Array.wrap(permitted[:remove_attachment_ids]).compact_blank.map(&:to_i)
  end

  def attach_suggestion_images!(record, signed_ids)
    signed_ids.each do |signed_id|
      blob = ActiveStorage::Blob.find_signed(signed_id)
      next if blob.blank?

      record.images.attach(blob)
    end
  end

  def purge_suggestion_attachments!(record, attachment_ids)
    return if attachment_ids.blank?

    record.images.attachments.where(id: attachment_ids).find_each(&:purge)
  end
end
