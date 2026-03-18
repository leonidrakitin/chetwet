# == Schema Information
#
# Table name: channel_telegram_personal
#
#  id                :bigint           not null, primary key
#  last_error        :text
#  status            :string           default("disconnected"), not null
#  telegram_user_id  :string
#  telegram_username :string
#  title             :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :integer          not null
#

class Channel::TelegramPersonal < ApplicationRecord
  include Channelable

  self.table_name = 'channel_telegram_personal'

  EDITABLE_ATTRS = [:title].freeze

  def name
    'Telegram Personal'
  end

  def display_name
    title.presence || telegram_username.presence || phone_number.presence || 'Telegram Personal'
  end

  def phone_number
    telegram_session&.phone_number
  end

  def connection_status
    telegram_session&.status || status
  end

  def telegram_session
    inbox&.telegram_session
  end

  def telegram_user_id
    self[:telegram_user_id].presence || telegram_session&.telegram_user_id
  end

  def telegram_username
    self[:telegram_username].presence || telegram_session&.telegram_username
  end

  def send_message_on_telegram(message)
    Telegram::MessageService.new(message: message).perform
  end
end
