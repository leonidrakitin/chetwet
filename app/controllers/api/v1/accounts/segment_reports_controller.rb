class Api::V1::Accounts::SegmentReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  SEGMENT_DEFINITIONS = [
    { name: 'Лояльные', color: '#4CAF50', recency_max: 14, min_created_days: 31 },
    { name: 'Новички', color: '#2196F3', max_created_days: 30 },
    { name: 'В зоне риска', color: '#FF9800', recency_range: 15..60 },
    { name: 'Ближайшие потери', color: '#F44336', recency_range: 61..120 },
    { name: 'Прочие', color: '#9C27B0' }
  ].freeze

  SEGMENT_CRITERIA = {
    'Лояльные' => 'Контакт создан более 30 дней назад, последняя активность менее 14 дней назад',
    'Новички' => 'Контакт создан в последние 30 дней',
    'В зоне риска' => 'Последняя активность от 15 до 60 дней назад',
    'Ближайшие потери' => 'Последняя активность от 61 до 120 дней назад',
    'Прочие' => 'Последняя активность более 120 дней назад'
  }.freeze

  SUGGESTIONS = {
    'Лояльные' => [
      'Запустить реферальную программу для лояльных клиентов',
      'Предложить эксклюзивные скидки за долгосрочное сотрудничество',
      'Создать VIP-программу с персональным менеджером'
    ],
    'Новички' => [
      'Настроить onboarding-цепочку приветственных писем',
      'Предложить бонус за первую покупку',
      'Провести опрос для выявления потребностей'
    ],
    'В зоне риска' => [
      'Отправить персонализированное предложение с ограниченным сроком',
      'Провести опрос причин снижения активности',
      'Запустить ретаргетинг-кампанию'
    ],
    'Ближайшие потери' => [
      'Срочно связаться через предпочтительный канал',
      'Предложить значительную скидку на возврат',
      'Анализировать причины оттока через exit-survey'
    ],
    'Прочие' => [
      'Запустить win-back email-кампанию',
      'Проверить актуальность контактных данных',
      'Рассмотреть удаление неактивных контактов'
    ]
  }.freeze

  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE = 50

  def summary
    contacts = Current.account.contacts
    total = contacts.count
    segments_data = compute_segments(contacts, total)
    total_revenue = segments_data.sum { |s| s[:revenue] }

    render json: {
      total_clients: total,
      total_revenue: total_revenue,
      segments: segments_data.map { |s| s.slice(:name, :count, :revenue, :color) },
      distribution: segments_data.map { |s| { name: s[:name], value: s[:percentage], color: s[:color] } }
    }
  end

  def details
    segment_name = params[:segment_name]
    return render json: { error: 'Segment not found' }, status: :not_found unless valid_segment?(segment_name)

    contacts = Current.account.contacts
    segment_contacts = contacts_for_segment(contacts, segment_name)
    total_in_segment = segment_contacts.count

    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, DEFAULT_PER_PAGE).to_i, MAX_PER_PAGE].min
    paginated = segment_contacts.order(last_activity_at: :desc).offset((page - 1) * per_page).limit(per_page)

    recent_changes = compute_recent_changes(contacts, segment_name)

    render json: {
      segment_name: segment_name,
      criteria: SEGMENT_CRITERIA[segment_name],
      total_clients_in_segment: total_in_segment,
      recent_changes: recent_changes,
      avg_metrics: compute_avg_metrics(segment_contacts),
      clients: serialize_clients(paginated),
      notifications: mock_notifications(segment_name),
      improvement_suggestions: SUGGESTIONS.fetch(segment_name, []),
      pagination: { page: page, per_page: per_page, total: total_in_segment, total_pages: (total_in_segment.to_f / per_page).ceil }
    }
  end

  def trends
    months = [params.fetch(:months, 6).to_i, 12].min
    contacts = Current.account.contacts.select(:id, :created_at, :last_activity_at)

    data = (0...months).map do |i|
      date = i.months.ago.end_of_month
      month_label = I18n.l(date, format: '%b %Y')
      counts = count_segments_at(contacts, date)
      { month: month_label, date: date.iso8601, **counts }
    end.reverse

    render json: { trends: data, segment_names: SEGMENT_DEFINITIONS.map { |s| s[:name] } }
  end

  def export
    segment_name = params[:segment_name]
    return render json: { error: 'Segment not found' }, status: :not_found unless valid_segment?(segment_name)

    contacts = Current.account.contacts
    segment_contacts = contacts_for_segment(contacts, segment_name).order(last_activity_at: :desc).limit(MAX_PER_PAGE * 20)

    csv_data = generate_csv(segment_contacts)

    send_data csv_data, filename: "segment_#{segment_name}_#{Date.current}.csv", type: 'text/csv; charset=utf-8'
  end

  private

  def compute_segments(contacts, total)
    return SEGMENT_DEFINITIONS.map { |s| s.slice(:name, :color).merge(count: 0, revenue: 0, percentage: 0.0) } if total.zero?

    classified = contacts.select(:id, :created_at, :last_activity_at, :additional_attributes).find_each.each_with_object(
      Hash.new { |h, k| h[k] = { count: 0, revenue: 0 } }
    ) do |contact, acc|
      seg_name = classify_contact(contact)
      acc[seg_name][:count] += 1
      acc[seg_name][:revenue] += extract_revenue(contact)
    end

    SEGMENT_DEFINITIONS.map do |seg|
      data = classified[seg[:name]]
      count = data[:count]
      percentage = (count.to_f / total * 100).round(1)
      seg.slice(:name, :color).merge(count: count, revenue: data[:revenue], percentage: percentage)
    end
  end

  def classify_contact(contact)
    recency_days = compute_recency(contact)
    created_days_ago = ((Time.current - contact.created_at) / 1.day).to_i

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

  def compute_recency(contact)
    ref = contact.last_activity_at.presence || contact.created_at
    ((Time.current - ref) / 1.day).to_i
  end

  def extract_revenue(contact)
    attrs = contact.additional_attributes || {}
    (attrs['total_spent'] || attrs['revenue'] || 0).to_f.round(2)
  end

  def contacts_for_segment(contacts, segment_name)
    all_ids = contacts.select(:id, :created_at, :last_activity_at).find_each.select do |c|
      classify_contact(c) == segment_name
    end.map(&:id)
    contacts.where(id: all_ids)
  end

  def compute_recent_changes(contacts, segment_name)
    cutoff = 30.days.ago
    recent_contacts = contacts.where(created_at: cutoff..).select(:id, :created_at, :last_activity_at)

    joined = recent_contacts.count { |c| classify_contact(c) == segment_name }

    previously_active = contacts.where(last_activity_at: ..cutoff).select(:id, :created_at, :last_activity_at)
    left = previously_active.count do |c|
      old_recency = ((cutoff - (c.last_activity_at || c.created_at)) / 1.day).to_i
      old_recency <= 14 && classify_contact(c) != segment_name
    end

    { joined: joined, left: [left, 0].max }
  end

  def compute_avg_metrics(segment_contacts)
    total = segment_contacts.count
    return { avg_check: 0, avg_recency_days: 0, avg_purchase_count: 0 } if total.zero?

    sum_revenue = 0
    sum_recency = 0
    sum_purchases = 0

    segment_contacts.select(:id, :created_at, :last_activity_at, :additional_attributes).find_each do |c|
      attrs = c.additional_attributes || {}
      sum_revenue += (attrs['total_spent'] || attrs['revenue'] || 0).to_f
      sum_recency += compute_recency(c)
      sum_purchases += (attrs['purchase_count'] || 0).to_i
    end

    {
      avg_check: (sum_revenue / total).round(2),
      avg_recency_days: (sum_recency.to_f / total).round(1),
      avg_purchase_count: (sum_purchases.to_f / total).round(1)
    }
  end

  def serialize_clients(contacts)
    contacts.map do |c|
      attrs = c.additional_attributes || {}
      {
        id: c.id,
        name: c.name.presence || c.email.presence || "ID: #{c.id}",
        purchase_count: (attrs['purchase_count'] || 0).to_i,
        last_purchase: attrs['last_purchase'] || c.last_activity_at&.to_date&.iso8601,
        total_spent: (attrs['total_spent'] || attrs['revenue'] || 0).to_f.round(2)
      }
    end
  end

  def mock_notifications(segment_name)
    [
      { type: 'email', sent_at: 7.days.ago.to_date.iso8601, subject: "Рассылка для сегмента «#{segment_name}»" },
      { type: 'sms', sent_at: 14.days.ago.to_date.iso8601, subject: "SMS-напоминание для «#{segment_name}»" }
    ]
  end

  def count_segments_at(contacts, date)
    counts = Hash.new(0)
    contacts.where(created_at: ..date).find_each do |c|
      recency = ((date - (c.last_activity_at || c.created_at)) / 1.day).to_i
      created_ago = ((date - c.created_at) / 1.day).to_i

      seg = if created_ago <= 30
              'Новички'
            elsif recency <= 14
              'Лояльные'
            elsif recency <= 60
              'В зоне риска'
            elsif recency <= 120
              'Ближайшие потери'
            else
              'Прочие'
            end
      counts[seg] += 1
    end
    counts
  end

  def generate_csv(contacts)
    require 'csv'
    CSV.generate(col_sep: ';', encoding: 'UTF-8') do |csv|
      csv << ['ID', 'Имя', 'Кол-во покупок', 'Последняя покупка', 'Сумма (RUB)']
      serialize_clients(contacts).each do |c|
        csv << [c[:id], c[:name], c[:purchase_count], c[:last_purchase], c[:total_spent]]
      end
    end
  end

  def valid_segment?(name)
    SEGMENT_DEFINITIONS.any? { |s| s[:name] == name }
  end

  def check_authorization
    authorize :report, :view?
  end
end
