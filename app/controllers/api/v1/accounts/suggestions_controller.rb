class Api::V1::Accounts::SuggestionsController < Api::V1::Accounts::BaseController
  before_action :suggestion, only: [:show, :update, :destroy, :vote, :add_tag, :remove_tag]

  def index
    suggestions = Current.account.suggestions
                         .search_by(params[:query])
                         .by_status(params[:status])

    suggestions = if params[:sort] == 'latest'
                    suggestions.order(created_at: :desc)
                  else
                    suggestions.ordered_by_votes
                  end

    @suggestions = suggestions.includes(:user)
    @current_user_votes = SuggestionVote.where(suggestion_id: @suggestions.map(&:id), user_id: current_user.id)
                                        .index_by(&:suggestion_id)
  end

  def show; end

  def create
    @suggestion = Current.account.suggestions.create!(suggestion_params.merge(user: current_user))
  end

  def update
    @suggestion.update!(suggestion_params)
  end

  def destroy
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

  def suggestion
    @suggestion ||= Current.account.suggestions.find(params[:id])
  end

  def suggestion_params
    params.require(:suggestion).permit(:title, :description, :status, tags: [])
  end
end
