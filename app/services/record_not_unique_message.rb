# Maps PostgreSQL unique constraint names to user-facing copy for inbox/channel creation.
class RecordNotUniqueMessage
  I18N_SCOPE = 'errors.record_not_unique'.freeze

  CONSTRAINT_TO_KEY = {
    'index_telegram_sessions_on_phone_number' => 'telegram_session_phone',
    'index_channel_telegram_personal_on_telegram_user_id_unique' => 'telegram_personal_user',
    'index_channel_email_on_email' => 'channel_email',
    'index_channel_email_on_forward_to_email' => 'channel_forward_to_email',
    'index_channel_sms_on_phone_number' => 'channel_sms_phone',
    'index_channel_whatsapp_on_phone_number' => 'channel_whatsapp_phone',
    'index_channel_telegram_on_bot_token' => 'channel_telegram_bot_token',
    'index_channel_line_on_line_channel_id' => 'channel_line',
    'index_channel_vk_on_group_id' => 'channel_vk_group',
    'index_channel_avito_on_client_id' => 'channel_avito',
    'index_channel_tiktok_on_business_id' => 'channel_tiktok',
    'index_channel_instagram_on_instagram_id' => 'channel_instagram',
    'index_channel_twilio_sms_on_phone_number' => 'channel_twilio_phone',
    'index_channel_twilio_sms_on_messaging_service_sid' => 'channel_twilio_messaging_service',
    'index_channel_twilio_sms_on_account_sid_and_phone_number' => 'channel_twilio_account_phone',
    'index_channel_api_on_hmac_token' => 'channel_api_hmac',
    'index_channel_api_on_identifier' => 'channel_api_identifier',
    'index_channel_web_widgets_on_website_token' => 'channel_web_widget_token',
    'index_channel_web_widgets_on_hmac_token' => 'channel_web_widget_hmac',
    'index_channel_facebook_pages_on_page_id_and_account_id' => 'channel_facebook_page',
    'index_channel_twitter_profiles_on_account_id_and_profile_id' => 'channel_twitter_profile',
    'index_channel_voice_on_phone_number' => 'channel_voice_phone'
  }.freeze

  def self.for(exception)
    new(exception).message
  end

  def initialize(exception)
    @exception = exception
  end

  def message
    constraint = extract_constraint_name
    key = CONSTRAINT_TO_KEY[constraint]
    return I18n.t("#{I18N_SCOPE}.#{key}") if key

    I18n.t("#{I18N_SCOPE}.default")
  end

  private

  def extract_constraint_name
    detail = @exception.cause&.message || @exception.message
    detail.match(/unique constraint "([^"]+)"/)&.[](1)
  end
end
