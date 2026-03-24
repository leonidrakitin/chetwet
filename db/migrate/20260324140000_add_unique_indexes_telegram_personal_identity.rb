class AddUniqueIndexesTelegramPersonalIdentity < ActiveRecord::Migration[7.1]
  def up
    deduplicate_telegram_sessions_by_phone
    deduplicate_channel_telegram_personal_by_telegram_user_id

    remove_index :telegram_sessions, name: 'index_telegram_sessions_on_phone_number', if_exists: true
    add_index :telegram_sessions, :phone_number, unique: true, name: 'index_telegram_sessions_on_phone_number'

    add_index :channel_telegram_personal, :telegram_user_id,
              unique: true,
              where: "telegram_user_id IS NOT NULL AND telegram_user_id <> ''",
              name: 'index_channel_telegram_personal_on_telegram_user_id_unique'
  end

  def down
    remove_index :channel_telegram_personal, name: 'index_channel_telegram_personal_on_telegram_user_id_unique', if_exists: true
    remove_index :telegram_sessions, name: 'index_telegram_sessions_on_phone_number', if_exists: true
    add_index :telegram_sessions, :phone_number, name: 'index_telegram_sessions_on_phone_number'
  end

  private

  def deduplicate_telegram_sessions_by_phone
    duplicate_phones = TelegramSession.group(:phone_number).having('COUNT(*) > 1').pluck(:phone_number)
    duplicate_phones.each do |phone|
      sessions = TelegramSession.where(phone_number: phone).includes(:inbox).to_a
      keeper = sessions.max_by { |s| [session_priority(s), s.id] }
      (sessions - [keeper]).each do |session|
        destroy_inbox_for_telegram_session!(session)
      end
    end
  end

  def deduplicate_channel_telegram_personal_by_telegram_user_id
    dup_ids = Channel::TelegramPersonal
              .where.not(telegram_user_id: [nil, ''])
              .group(:telegram_user_id)
              .having('COUNT(*) > 1')
              .pluck(:telegram_user_id)
    dup_ids.each do |uid|
      channels = Channel::TelegramPersonal.where(telegram_user_id: uid).includes(:inbox).order(:id).to_a
      keeper = channels.last
      (channels - [keeper]).each do |channel|
        inbox = channel.inbox
        destroy_inbox_for_telegram_personal!(inbox) if inbox
      end
    end
  end

  def destroy_inbox_for_telegram_session!(session)
    inbox = session.inbox
    destroy_inbox_for_telegram_personal!(inbox) if inbox
  end

  def session_priority(session)
    return 2 if session.active?
    return 1 if session.authenticating?

    0
  end

  def destroy_inbox_for_telegram_personal!(inbox)
    session_ids = ::TelegramSession.where(inbox_id: inbox.id).pluck(:id)
    if session_ids.any?
      # rubocop:disable Rails/SkipsModelValidations -- migration backfill; preserve rows
      ::BulkMigration.where(telegram_session_id: session_ids).update_all(telegram_session_id: nil)
      # rubocop:enable Rails/SkipsModelValidations
      ::TelegramSession.where(inbox_id: inbox.id).delete_all
    end
    ::BulkMigration.where(inbox_id: inbox.id).delete_all
    ::DeleteObjectJob.perform_now(inbox)
  end
end
