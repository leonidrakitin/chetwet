class Api::V1::Accounts::LlmUsagesController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    since_date = parse_date(params[:since])
    until_date = parse_date(params[:until])

    render json: {
      payload: LlmUsage.summary_for_account(Current.account.id, since_date: since_date, until_date: until_date)
    }
  end

  def for_conversation
    conversation = Current.account.conversations.find_by(display_id: params[:conversation_id])
    return render json: { error: 'Conversation not found' }, status: :not_found unless conversation

    render json: {
      payload: LlmUsage.summary_for_conversation(conversation.id)
    }
  end

  private

  def parse_date(date_string)
    return nil if date_string.blank?

    Time.zone.parse(date_string)
  rescue ArgumentError
    nil
  end
end
