class Captain::AssistantTemplates::Loader
  TEMPLATES_DIR = Rails.root.join('config/captain/assistant_templates')
  SUPPORTED_LOCALES = %w[en ru].freeze
  DEFAULT_LOCALE = 'en'.freeze

  class << self
    def all
      Dir[TEMPLATES_DIR.join('*.yml')].map { |path| load_file(path) }
    end

    def find(template_id)
      path = TEMPLATES_DIR.join("#{template_id}.yml")
      raise Captain::AssistantTemplates::TemplateNotFoundError, "Template '#{template_id}' not found" unless File.exist?(path)

      load_file(path)
    end

    def preview_list(locale:)
      all.map { |template| preview(template, locale: locale) }
    end

    def preview(template, locale:)
      loc = resolve_locale(locale)
      assistant = template['assistant'] || {}

      base_preview(template, assistant, loc).merge(
        scenarios: scenarios_preview(template['scenarios'], loc),
        faq_count: (template['faq_seed'] || []).size,
        documents_seed: documents_preview(template['documents_seed'], loc)
      )
    end

    def resolve_locale(locale)
      return DEFAULT_LOCALE if locale.blank?

      normalized = locale.to_s.downcase.split('-').first
      SUPPORTED_LOCALES.include?(normalized) ? normalized : DEFAULT_LOCALE
    end

    def localized(i18n_hash, locale)
      return nil unless i18n_hash.is_a?(Hash)

      i18n_hash[locale] || i18n_hash[DEFAULT_LOCALE] || i18n_hash.values.first
    end

    private

    def load_file(path)
      YAML.load_file(path)
    end

    def base_preview(template, assistant, loc)
      {
        id: template['id'],
        industry: template['industry'],
        subtype: template['subtype'],
        name: localized(assistant['name_i18n'], loc),
        description: localized(assistant['description_i18n'], loc),
        product_name_placeholder: assistant['product_name_placeholder'],
        tone: assistant['tone'],
        knowledge_mode: assistant['knowledge_mode'],
        recommended_tools: template.fetch('recommended_tools', [])
      }
    end

    def scenarios_preview(scenarios, loc)
      (scenarios || []).map do |s|
        {
          key: s['key'],
          role: s['role'],
          title: localized(s['title_i18n'], loc),
          description: localized(s['description_i18n'], loc)
        }
      end
    end

    def documents_preview(documents, loc)
      (documents || []).map do |d|
        {
          title: localized(d['title_i18n'], loc),
          hint: localized(d['hint_i18n'], loc)
        }
      end
    end
  end
end
