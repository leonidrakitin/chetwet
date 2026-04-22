class Campaigns::StatisticsService
  PERIODS = {
    '7d' => 7.days,
    '14d' => 14.days,
    '30d' => 30.days,
    '90d' => 90.days
  }.freeze

  def initialize(account, period: '30d')
    @account = account
    @period = period
    @period_days = PERIODS[period] || 30.days
  end

  def call
    {
      summary: build_summary,
      by_campaign: build_by_campaign,
      time_series: build_time_series,
      scheduled: build_scheduled
    }
  end

  def for_campaign(campaign)
    {
      summary: build_campaign_summary(campaign),
      time_series: build_campaign_time_series(campaign),
      deliveries_by_status: deliveries_by_status(campaign),
      recent_deliveries: recent_deliveries(campaign)
    }
  end

  private

  def build_summary
    deliveries = @account.campaign_deliveries
    campaigns = @account.campaigns

    status_counts = deliveries.group(:status).count
    sent = status_counts['sent'] || 0
    failed = status_counts['failed'] || 0
    skipped = status_counts['skipped'] || 0
    replied = status_counts['replied'] || 0
    total = sent + failed + skipped + replied

    {
      total_campaigns: campaigns.count,
      active_campaigns: campaigns.active.count,
      total_deliveries: total,
      sent: sent,
      failed: failed,
      skipped: skipped,
      replied: replied,
      success_rate: calculate_rate(sent, total),
      reply_rate: calculate_rate(replied, sent),
      scheduled_count: campaigns.where('scheduled_at > ?', Time.current).count
    }
  end

  def build_by_campaign
    raw = @account.campaign_deliveries.group(:campaign_id, :status).count
    first_sent = @account.campaign_deliveries.group(:campaign_id).minimum(:sent_at)
    last_sent = @account.campaign_deliveries.group(:campaign_id).maximum(:sent_at)
    unique_recipients = @account.campaign_deliveries.group(:campaign_id).distinct.count(:contact_id)

    stats = build_campaign_stats(raw)
    enrich_campaign_stats(stats, first_sent, last_sent, unique_recipients)
    stats
  end

  def build_campaign_stats(raw)
    stats = {}
    raw.each do |(campaign_id, status), count|
      stats[campaign_id] ||= init_campaign_stats
      stats[campaign_id][status.to_sym] = count
      stats[campaign_id][:total] += count
    end
    stats
  end

  def enrich_campaign_stats(stats, first_sent, last_sent, unique_recipients)
    stats.each do |campaign_id, s|
      s[:unique_recipients] = unique_recipients[campaign_id] || 0
      s[:first_sent_at] = first_sent[campaign_id]
      s[:last_sent_at] = last_sent[campaign_id]
      s[:delivery_rate] = calculate_rate(s[:sent], s[:sent] + s[:failed])
      s[:reply_rate] = calculate_rate(s[:replied], s[:sent])
      s[:skip_rate] = calculate_rate(s[:skipped], s[:total])
      s[:failure_rate] = calculate_rate(s[:failed], s[:total])
    end
  end

  def build_time_series
    start_date = @period_days.ago.to_date
    end_date = Date.current

    deliveries_by_date = fetch_deliveries_by_date(start_date)
    replies_by_date = fetch_replies_by_date(start_date)
    date_range = (start_date..end_date).to_a

    {
      period: @period,
      start_date: start_date.to_s,
      end_date: end_date.to_s,
      deliveries: build_deliveries_series(date_range, deliveries_by_date),
      replies: build_replies_series(date_range, replies_by_date)
    }
  end

  def fetch_deliveries_by_date(start_date)
    @account.campaign_deliveries
            .where('sent_at >= ?', start_date.beginning_of_day)
            .group('DATE(sent_at)', :status)
            .count
  end

  def fetch_replies_by_date(start_date)
    @account.campaign_deliveries
            .where(status: 'replied')
            .where('sent_at >= ?', start_date.beginning_of_day)
            .group('DATE(sent_at)')
            .count
  end

  def build_deliveries_series(date_range, deliveries_by_date)
    date_range.map do |date|
      date_str = date.to_s
      {
        date: date_str,
        sent: deliveries_by_date[[date_str, 'sent']] || 0,
        failed: deliveries_by_date[[date_str, 'failed']] || 0,
        skipped: deliveries_by_date[[date_str, 'skipped']] || 0,
        replied: deliveries_by_date[[date_str, 'replied']] || 0
      }
    end
  end

  def build_replies_series(date_range, replies_by_date)
    date_range.map do |date|
      date_str = date.to_s
      { date: date_str, count: replies_by_date[date_str] || 0 }
    end
  end

  def build_scheduled
    @account.campaigns
            .where('scheduled_at > ?', Time.current)
            .order(scheduled_at: :asc)
            .limit(20)
            .map do |campaign|
              {
                id: campaign.id,
                name: campaign.name,
                scheduled_at: campaign.scheduled_at.iso8601,
                enabled: campaign.enabled,
                inbox_name: campaign.inbox&.name
              }
            end
  end

  def build_campaign_summary(campaign)
    deliveries = campaign.deliveries

    status_counts = deliveries.group(:status).count
    sent = status_counts['sent'] || 0
    failed = status_counts['failed'] || 0
    skipped = status_counts['skipped'] || 0
    replied = status_counts['replied'] || 0
    total = sent + failed + skipped + replied

    {
      sent: sent,
      failed: failed,
      skipped: skipped,
      replied: replied,
      total: total,
      unique_recipients: deliveries.distinct.count(:contact_id),
      first_sent_at: deliveries.minimum(:sent_at)&.iso8601,
      last_sent_at: deliveries.maximum(:sent_at)&.iso8601,
      delivery_rate: calculate_rate(sent, sent + failed),
      reply_rate: calculate_rate(replied, sent),
      skip_rate: calculate_rate(skipped, total),
      failure_rate: calculate_rate(failed, total)
    }
  end

  def build_campaign_time_series(campaign)
    start_date = @period_days.ago.to_date
    end_date = Date.current

    deliveries_by_date = campaign.deliveries
                                 .where('sent_at >= ?', start_date.beginning_of_day)
                                 .group('DATE(sent_at)', :status)
                                 .count

    (start_date..end_date).to_a.map do |date|
      date_str = date.to_s
      {
        date: date_str,
        sent: deliveries_by_date[[date_str, 'sent']] || 0,
        failed: deliveries_by_date[[date_str, 'failed']] || 0,
        skipped: deliveries_by_date[[date_str, 'skipped']] || 0,
        replied: deliveries_by_date[[date_str, 'replied']] || 0
      }
    end
  end

  def deliveries_by_status(campaign)
    campaign.deliveries.group(:status).count
  end

  def recent_deliveries(campaign, limit: 50)
    campaign.deliveries
            .includes(:contact, :conversation)
            .order(created_at: :desc)
            .limit(limit)
            .map do |delivery|
              {
                id: delivery.id,
                status: delivery.status,
                sent_at: delivery.sent_at&.iso8601,
                contact_name: delivery.contact&.name,
                contact_id: delivery.contact_id,
                conversation_id: delivery.conversation_id
              }
            end
  end

  def init_campaign_stats
    { sent: 0, failed: 0, skipped: 0, replied: 0, total: 0 }
  end

  def calculate_rate(numerator, denominator)
    return 0 if denominator.zero?

    ((numerator.to_f / denominator) * 100).round(2)
  end
end
