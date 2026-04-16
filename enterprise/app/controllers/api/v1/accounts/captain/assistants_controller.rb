class Api::V1::Accounts::Captain::AssistantsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action -> { check_authorization(Captain::Assistant) }

  before_action :set_assistant, only: [:show, :update, :destroy, :playground, :built_in_tools]

  def index
    @assistants = account_assistants.ordered
  end

  def show; end

  def create
    @assistant = account_assistants.create!(assistant_params)
  end

  def update
    @assistant.update!(assistant_params)
  end

  def destroy
    @assistant.destroy
    head :no_content
  end

  def playground
    response = if captain_v2_enabled?
                 Captain::Assistant::AgentRunnerService.new(assistant: @assistant, source: 'playground').generate_response(
                   message_history: playground_message_history
                 )
               else
                 Captain::Llm::AssistantChatService.new(assistant: @assistant, source: 'playground').generate_response(
                   additional_message: playground_params[:message_content],
                   message_history: message_history
                 )
               end

    render json: response
  end

  def tools
    assistant = Captain::Assistant.new(account: Current.account)
    @tools = assistant.available_agent_tools
  end

  def built_in_tools
    render json: @assistant.built_in_tools_with_status
  end

  private

  def set_assistant
    @assistant = account_assistants.find(params[:id])
  end

  def account_assistants
    @account_assistants ||= Captain::Assistant.for_account(Current.account.id)
  end

  def assistant_params
    permitted = params.require(:assistant).permit(:name, :description,
                                                  config: [
                                                    :product_name, :feature_faq, :feature_memory, :feature_citation,
                                                    :feature_document_faq_generation,
                                                    :feature_contact_attributes,
                                                    :welcome_message, :handoff_message, :resolution_message,
                                                    :instructions, :temperature,
                                                    :autonomy_max_retries, :faq_auto_answer_threshold, :faq_suggest_threshold,
                                                    :autonomy_self_check_enabled, :autonomy_return_to_scenario,
                                                    :knowledge_mode, :knowledge_answer_threshold,
                                                    :tone, :emojify,
                                                    { decision_maker_ids: [], allowed_emojis: [] }
                                                  ])

    merge_array_params(permitted)
    permitted
  end

  def merge_array_params(permitted)
    assistant_input = params[:assistant]
    permitted[:response_guidelines] = assistant_input[:response_guidelines] if assistant_input.key?(:response_guidelines)
    permitted[:guardrails] = assistant_input[:guardrails] if assistant_input.key?(:guardrails)

    return unless assistant_input.key?(:config) && assistant_input[:config].key?(:disabled_built_in_tools)

    permitted[:config] ||= {}
    permitted[:config][:disabled_built_in_tools] = assistant_input[:config][:disabled_built_in_tools]
  end

  def playground_params
    params.require(:assistant).permit(:message_content, message_history: [:role, :content, :agent_name])
  end

  def message_history
    (playground_params[:message_history] || []).map do |message|
      {
        role: message[:role],
        content: message[:content],
        agent_name: message[:agent_name]
      }.compact
    end
  end

  def playground_message_history
    history = message_history
    current_message = playground_params[:message_content]
    return history if current_message.blank?

    current_user_message = { role: 'user', content: current_message }
    return history if history.last == current_user_message

    history + [current_user_message]
  end

  def captain_v2_enabled?
    @assistant.account.feature_enabled?('captain_integration_v2')
  end
end
