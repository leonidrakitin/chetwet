# frozen_string_literal: true

# == Schema Information
#
# Table name: bulk_migrations
#
#  id                      :bigint           not null, primary key
#  config                  :jsonb            not null
#  dry_run                 :boolean          default(FALSE), not null
#  faqs_generated          :integer          default(0)
#  finished_at             :datetime
#  include_groups          :boolean          default(FALSE)
#  max_messages_per_dialog :integer
#  processed               :integer          default(0)
#  report                  :jsonb
#  skipped                 :integer          default(0)
#  source                  :string           not null
#  started_at              :datetime
#  status                  :string           default("pending"), not null
#  total_dialogs           :integer          default(0)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :bigint           not null
#  agent_external_id       :string
#  captain_assistant_id    :bigint           not null
#  inbox_id                :bigint           not null
#  telegram_session_id     :bigint
#
# Indexes
#
#  index_bulk_migrations_on_account_id                       (account_id)
#  index_bulk_migrations_on_account_id_and_status            (account_id,status)
#  index_bulk_migrations_on_captain_assistant_id             (captain_assistant_id)
#  index_bulk_migrations_on_captain_assistant_id_and_status  (captain_assistant_id,status)
#  index_bulk_migrations_on_inbox_id                         (inbox_id)
#  index_bulk_migrations_on_source                           (source)
#  index_bulk_migrations_on_telegram_session_id              (telegram_session_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (captain_assistant_id => captain_assistants.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (telegram_session_id => telegram_sessions.id)
#
class BulkMigration < ApplicationRecord
  belongs_to :account
  belongs_to :captain_assistant, class_name: 'Captain::Assistant'
  belongs_to :inbox
  belongs_to :telegram_session, optional: true

  has_one_attached :file

  enum status: {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }, _prefix: true, _default: 'pending'

  validates :source, presence: true, inclusion: { in: %w[telegram whatsapp vk telegram_personal vk_personal] }
  validates :total_dialogs, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :file_attached_and_json, unless: -> { source.in?(%w[telegram_personal vk_personal]) }
  validate :telegram_session_required, if: -> { source == 'telegram_personal' }
  validate :vk_token_required, if: -> { source == 'vk_personal' }

  scope :recent, -> { order(created_at: :desc) }

  def file_path
    return unless file.attached?

    service = file.blob.service
    service.respond_to?(:path_for) ? service.path_for(file.blob.key) : nil
  end

  def progress_percent
    return 0 if total_dialogs.to_i.zero?

    (processed.to_f / total_dialogs * 100).round(1)
  end

  def summary
    return (report['summary'] || report[:summary]) if report.present? && (report['summary'].present? || report[:summary].present?)

    "#{processed}/#{total_dialogs} диалогов обработано"
  end

  def session_gap_minutes
    config&.dig('session_gap_minutes')&.to_i
  end

  def faq_dedup_threshold
    config&.dig('faq_dedup_threshold')&.to_f
  end

  def dialog_dedup_threshold
    config&.dig('dialog_dedup_threshold')&.to_f
  end

  def date_limit_months
    config&.dig('date_limit_months')&.to_i
  end

  after_create_commit :enqueue_job, if: :status_pending?

  private

  def file_attached_and_json
    unless file.attached?
      errors.add(:file, :blank)
      return
    end

    return if file.blob.content_type.in?(['application/json', 'text/plain'])

    errors.add(:file, 'must be JSON')
  end

  def telegram_session_required
    errors.add(:telegram_session, :blank) if telegram_session_id.blank?
    errors.add(:telegram_session, 'must be active') if telegram_session_id.present? && !telegram_session&.active?
  end

  def vk_token_required
    errors.add(:config, 'must include vk_access_token') if config&.dig('vk_access_token').blank?
  end

  def enqueue_job
    BulkMigrationJob.perform_later(id, { dry_run: dry_run })
  end
end
