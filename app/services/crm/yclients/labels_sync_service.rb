# frozen_string_literal: true

class Crm::Yclients::LabelsSyncService
  def initialize(account, hook)
    @account = account
    @hook = hook
    @company_id = hook.settings['company_id']
    @categories_client = Crm::Yclients::Api::CategoriesClient.new(
      hook.settings['partner_token'],
      Crm::Yclients::HookResolver.user_token_for(hook),
      hook.settings['company_id']
    )
  end

  def sync
    categories = @categories_client.list
    synced = 0

    categories.each do |category|
      title = normalize_title(category['title'])
      next if title.blank?

      label = @account.labels.find_by('LOWER(title) = ?', title.downcase)
      if label
        update_label(label, category)
      else
        create_label(title, category)
      end
      synced += 1
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "YClients LabelsSyncService: failed to sync category #{category['id']}: #{e.message}"
    end

    synced
  end

  private

  def normalize_title(raw)
    raw.to_s.strip.gsub(/\s+/, ' ').presence
  end

  def create_label(title, category)
    @account.labels.create!(
      title: title,
      description: "YClients: #{category['title']}",
      color: '#1f93ff',
      show_on_sidebar: false
    )
  end

  def update_label(label, category)
    desc = "YClients: #{category['title']}"
    label.update!(description: desc) if label.description.blank? || label.description.start_with?('YClients:')
  end
end
