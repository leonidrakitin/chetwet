class SuperAdmin::SuggestionsController < SuperAdmin::ApplicationController
  def index
    @suggestions = Suggestion.includes(:user, :account).order(created_at: :desc)
    @suggestions = @suggestions.by_status(params[:status]) if params[:status].present?
    @suggestions = @suggestions.search_by(params[:query]) if params[:query].present?
  end

  def show
    @suggestion = Suggestion.includes(images_attachments: :blob).find(params[:id])
  end

  def destroy
    suggestion = Suggestion.find(params[:id])
    suggestion.destroy!
    redirect_to super_admin_suggestions_path, notice: 'Suggestion deleted'
  end

  def approve
    suggestion = Suggestion.find(params[:id])
    suggestion.update!(status: 'approved')
    redirect_to super_admin_suggestion_path(suggestion), notice: 'Suggestion approved'
  end

  def reject
    suggestion = Suggestion.find(params[:id])
    suggestion.update!(status: 'rejected')
    redirect_to super_admin_suggestion_path(suggestion), notice: 'Suggestion rejected'
  end

  def add_tag
    suggestion = Suggestion.find(params[:id])
    suggestion.add_tag(params[:tag])
    redirect_to super_admin_suggestion_path(suggestion), notice: 'Tag added'
  end

  def remove_tag
    suggestion = Suggestion.find(params[:id])
    suggestion.remove_tag(params[:tag])
    redirect_to super_admin_suggestion_path(suggestion), notice: 'Tag removed'
  end
end
