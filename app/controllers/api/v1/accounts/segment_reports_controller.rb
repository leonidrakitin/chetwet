class Api::V1::Accounts::SegmentReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  SEGMENT_DEFINITIONS = [
    { name: 'Лояльные', color: '#4CAF50' },
    { name: 'Новички', color: '#2196F3' },
    { name: 'В зоне риска', color: '#FF9800' },
    { name: 'Ближайшие потери', color: '#F44336' },
    { name: 'Прочие', color: '#9C27B0' }
  ].freeze

  def summary
    contacts = Current.account.contacts
    total = contacts.count

    segments = compute_segments(contacts, total)

    render json: {
      total_clients: total,
      segments: segments.map { |s| s.slice(:name, :count, :color) },
      distribution: segments.map { |s| { name: s[:name], value: s[:percentage], color: s[:color] } }
    }
  end

  private

  def compute_segments(contacts, total)
    return SEGMENT_DEFINITIONS.map { |s| s.merge(count: 0, percentage: 0.0) } if total.zero?

    scored = contacts.select(:id, :created_at, :last_activity_at).find_each.map do |contact|
      classify_contact(contact)
    end

    counts = scored.tally

    SEGMENT_DEFINITIONS.map do |seg|
      count = counts[seg[:name]] || 0
      percentage = (count.to_f / total * 100).round(1)
      seg.merge(count: count, percentage: percentage)
    end
  end

  def classify_contact(contact)
    recency_days = if contact.last_activity_at.present?
                     (Time.current - contact.last_activity_at).to_i / 1.day
                   else
                     (Time.current - contact.created_at).to_i / 1.day
                   end

    created_days_ago = (Time.current - contact.created_at).to_i / 1.day

    if created_days_ago <= 30
      'Новички'
    elsif recency_days <= 14
      'Лояльные'
    elsif recency_days <= 60
      'В зоне риска'
    elsif recency_days <= 120
      'Ближайшие потери'
    else
      'Прочие'
    end
  end

  def check_authorization
    authorize :report, :view?
  end
end
