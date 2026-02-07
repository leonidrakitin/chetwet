# frozen_string_literal: true

class Webhooks::VkController < ActionController::API
  def process_payload
    params_hash = params.to_unsafe_hash.with_indifferent_access

    if params_hash[:type] == 'confirmation'
      handle_confirmation(params_hash)
    else
      Webhooks::VkEventsJob.perform_later(params_hash)
      head :ok
    end
  end

  private

  def handle_confirmation(params_hash)
    group_id = params_hash[:group_id]&.to_s
    channel = Channel::Vk.find_by(group_id: group_id)

    confirmation_string = channel&.secret.presence || ''

    render plain: confirmation_string
  end
end
