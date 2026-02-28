# frozen_string_literal: true

class BulkMigration < ApplicationRecord
  belongs_to :account
  belongs_to :captain_assistant, class_name: 'Captain::Assistant'
  belongs_to :inbox

  has_one_attached :file

  enum status: {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }, _prefix: true, _default: 'pending'

  validates :source, presence: true, inclusion: { in: %w[telegram whatsapp vk] }
  validates :total_dialogs, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :file_attached_and_json

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

  def enqueue_job
    BulkMigrationJob.perform_later(id, { dry_run: dry_run })
  end
end
