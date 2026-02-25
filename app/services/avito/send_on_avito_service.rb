# frozen_string_literal: true

class Avito::SendOnAvitoService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Avito
  end

  def perform_reply
    message_id = channel.send_message_on_avito(message)
    message.update!(source_id: message_id.to_s) if message_id.present?
  end

  def inbox
    @inbox ||= message.inbox
  end

  def channel
    @channel ||= inbox.channel
  end
end
