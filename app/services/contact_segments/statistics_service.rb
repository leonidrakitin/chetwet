class ContactSegments::StatisticsService
  PERIOD_DAYS = 30

  def initialize(segment)
    @segment = segment
    @account = segment.account
  end

  def call
    {
      members_count: members_count,
      total_contacts_count: total_contacts_count,
      percent_of_total: percent_of_total,
      entered_count: entered_count,
      exited_count: exited_count,
      period_days: PERIOD_DAYS
    }
  end

  private

  def members_count
    @members_count ||= @segment.memberships.count
  end

  def total_contacts_count
    @total_contacts_count ||= @account.contacts.count
  end

  def percent_of_total
    return 0 if total_contacts_count.zero?

    (members_count.to_f / total_contacts_count * 100).round(1)
  end

  def period_start
    @period_start ||= PERIOD_DAYS.days.ago
  end

  def entered_count
    @segment.change_logs.enter.where('detected_at >= ?', period_start).count
  end

  def exited_count
    @segment.change_logs.exit.where('detected_at >= ?', period_start).count
  end
end
