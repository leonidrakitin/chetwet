class ContactSegments::MembershipEvaluationService
  def initialize(segment:, trigger_source:, reason: nil, contact_ids: nil)
    @segment = segment
    @trigger_source = trigger_source
    @reason = reason
    @contact_ids = contact_ids
  end

  def call
    current_member_ids = evaluate_segment_query
    previous_member_ids = relevant_previous_member_ids

    entered = current_member_ids - previous_member_ids
    exited = previous_member_ids - current_member_ids

    process_entered(entered)
    process_exited(exited)

    { entered: entered.size, exited: exited.size }
  end

  private

  def evaluate_segment_query
    result = ::Contacts::NestedFilterService.new(@segment.account, @segment.query).perform
    contact_ids = result[:contacts].pluck(:id)

    # If evaluating specific contacts, intersect with the full result
    if @contact_ids.present?
      contact_ids & @contact_ids
    else
      contact_ids
    end
  end

  def relevant_previous_member_ids
    if @contact_ids.present?
      @segment.memberships.where(contact_id: @contact_ids).pluck(:contact_id)
    else
      @segment.membership_ids
    end
  end

  def process_entered(contact_ids)
    return if contact_ids.empty?

    now = Time.current

    # Bulk insert memberships
    membership_records = contact_ids.map do |contact_id|
      { contact_id: contact_id, contact_segment_id: @segment.id, created_at: now, updated_at: now }
    end
    ContactSegmentMembership.insert_all(membership_records)

    # Bulk insert change logs
    log_records = contact_ids.map do |contact_id|
      {
        contact_id: contact_id,
        contact_segment_id: @segment.id,
        action: 'enter',
        trigger_source: @trigger_source,
        reason: @reason,
        detected_at: now,
        created_at: now,
        updated_at: now
      }
    end
    SegmentChangeLog.insert_all(log_records)

    # Dispatch events
    contact_ids.each do |contact_id|
      Rails.configuration.dispatcher.dispatch(
        SEGMENT_CONTACT_ENTERED,
        now,
        contact_id: contact_id,
        segment: @segment,
        action: 'enter',
        trigger_source: @trigger_source,
        reason: @reason,
        account: @segment.account
      )
    end
  end

  def process_exited(contact_ids)
    return if contact_ids.empty?

    now = Time.current

    # Remove memberships
    @segment.memberships.where(contact_id: contact_ids).delete_all

    # Bulk insert change logs
    log_records = contact_ids.map do |contact_id|
      {
        contact_id: contact_id,
        contact_segment_id: @segment.id,
        action: 'exit',
        trigger_source: @trigger_source,
        reason: @reason,
        detected_at: now,
        created_at: now,
        updated_at: now
      }
    end
    SegmentChangeLog.insert_all(log_records)

    # Dispatch events
    contact_ids.each do |contact_id|
      Rails.configuration.dispatcher.dispatch(
        SEGMENT_CONTACT_EXITED,
        now,
        contact_id: contact_id,
        segment: @segment,
        action: 'exit',
        trigger_source: @trigger_source,
        reason: @reason,
        account: @segment.account
      )
    end
  end
end
