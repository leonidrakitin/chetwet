class Inbox::TelegramPersonalService
  pattr_initialize [:account!, :user!, :params!]

  def perform
    ActiveRecord::Base.transaction do
      channel = build_channel
      inbox = build_inbox(channel)
      session = build_session(inbox)

      # Важно: сначала сохраняем сущности Chatwoot, затем запускаем TDLib auth flow.
      Telegram::AuthenticationService.new(telegram_session: session).start_authentication!

      { inbox: inbox, telegram_session: session }
    end
  end

  private

  def build_channel
    account.telegram_personal_channels.create!(
      title: params[:name].presence,
      status: 'authenticating'
    )
  end

  def build_inbox(channel)
    account.inboxes.create!(
      name: params[:name].presence || params[:phone_number],
      channel: channel
    )
  end

  def build_session(inbox)
    TelegramSession.create!(
      phone_number: params[:phone_number],
      api_id: params[:api_id],
      api_hash: params[:api_hash],
      user: user,
      inbox: inbox,
      status: :authenticating,
      auth_state: 'wait_phone_number'
    )
  end
end
