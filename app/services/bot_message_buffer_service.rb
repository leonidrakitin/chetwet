class BotMessageBufferService
  BUFFER_TTL = 30
  IMMEDIATE_LENGTH = 120
  QUESTION_DELAY = 2
  DEFAULT_DELAY = 4

  def initialize(conversation_id, bot_type, bot_id)
    @conversation_id = conversation_id
    @bot_type = bot_type
    @bot_id = bot_id
  end

  def schedule(message)
    init_start_id(message.id)
    token = SecureRandom.uuid
    store_token(token)
    delay = compute_delay(message)
    BotMessageBufferJob.set(wait: delay.seconds).perform_later(@conversation_id, @bot_type, @bot_id, token)
  end

  def valid_token?(token)
    ::Redis::Alfred.get(token_key) == token
  end

  def flush_messages
    start_id = ::Redis::Alfred.get(start_id_key)
    return Message.none if start_id.nil?

    messages = Message.where(conversation_id: @conversation_id)
                      .where('id >= ?', start_id.to_i)
                      .where(message_type: :incoming)
                      .order(:created_at)
    ::Redis::Alfred.delete(token_key)
    ::Redis::Alfred.delete(start_id_key)
    messages
  end

  private

  def token_key
    format(::Redis::Alfred::BOT_BUFFER_TOKEN, conversation_id: @conversation_id, bot_type: @bot_type, bot_id: @bot_id)
  end

  def start_id_key
    format(::Redis::Alfred::BOT_BUFFER_START_ID, conversation_id: @conversation_id, bot_type: @bot_type, bot_id: @bot_id)
  end

  def init_start_id(message_id)
    ::Redis::Alfred.set(start_id_key, message_id, nx: true, ex: BUFFER_TTL)
  end

  def store_token(token)
    ::Redis::Alfred.set(token_key, token, ex: BUFFER_TTL)
  end

  def compute_delay(message)
    content = message.content.to_s
    return 0 if content.length > IMMEDIATE_LENGTH

    @bot_type == 'captain' ? captain_buffer_seconds : non_captain_delay(content)
  end

  def captain_buffer_seconds
    conversation = Conversation.find_by(id: @conversation_id)
    seconds = conversation&.account&.captain_message_buffer_seconds.presence&.to_i
    seconds&.between?(1, 30) ? seconds : DEFAULT_DELAY
  end

  def non_captain_delay(content)
    content.include?('?') ? QUESTION_DELAY : DEFAULT_DELAY
  end
end
