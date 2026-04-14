# frozen_string_literal: true

module NormalizesScheduleWorkingHours
  extend ActiveSupport::Concern

  private

  def normalize_day_config(day_config)
    case day_config
    when Hash
      normalize_hash_day_config(day_config)
    when Array
      slots = normalize_slots(day_config)
      { 'enabled' => slots.any?, 'slots' => slots }
    when String
      normalize_string_day_config(day_config)
    else
      { 'enabled' => false, 'slots' => [] }
    end
  end

  def normalize_hash_day_config(day_config)
    slots = normalize_slots(day_config['slots'] || day_config[:slots])
    enabled = if day_config.key?('enabled') || day_config.key?(:enabled)
                ActiveModel::Type::Boolean.new.cast(day_config['enabled'].nil? ? day_config[:enabled] : day_config['enabled'])
              else
                slots.any?
              end

    { 'enabled' => enabled, 'slots' => slots }
  end

  def normalize_string_day_config(day_config)
    parsed_day_config = parse_json_day_config(day_config)
    return normalize_day_config(parsed_day_config) if parsed_day_config

    slots = normalize_slots(day_config.split(/[;,]/))
    { 'enabled' => slots.any?, 'slots' => slots }
  end

  def parse_json_day_config(day_config)
    JSON.parse(day_config)
  rescue JSON::ParserError, TypeError
    nil
  end

  def normalize_slots(slots)
    Array(slots).filter_map do |slot|
      normalize_slot(slot)
    end
  end

  def normalize_slot(slot)
    case slot
    when Hash
      start_time = slot['start'] || slot[:start]
      end_time = slot['end'] || slot[:end]
      return unless start_time.present? && end_time.present?

      { 'start' => start_time, 'end' => end_time }
    when String
      normalized_slot = slot.strip
      match = normalized_slot.match(/\A(?<start>\d{1,2}:\d{2})\s*-\s*(?<end>\d{1,2}:\d{2})\z/)
      return unless match

      { 'start' => match[:start], 'end' => match[:end] }
    end
  end
end
