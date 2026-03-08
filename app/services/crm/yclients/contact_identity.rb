class Crm::Yclients::ContactIdentity
  class << self
    def external_id_for(contact, company_id: nil)
      external = external_attributes(contact)
      company_mappings = normalized_company_ids(external)

      if company_id.present?
        return company_mappings[company_id.to_s] if company_mappings.any?

        return external['yclients_id']
      end

      external['yclients_id']
    end

    def company_ids(contact)
      normalized_company_ids(external_attributes(contact)).keys
    end

    def find_contact_by_external_id(account, external_id, company_id: nil)
      return if external_id.blank?

      company_id = company_id.to_s if company_id.present?

      if company_id.present?
        contact = account.contacts.find_by(
          "additional_attributes -> 'external' -> 'yclients_ids' ->> ? = ?",
          company_id,
          external_id.to_s
        )
        return contact if contact.present?
      end

      account.contacts.find_by(
        "additional_attributes -> 'external' ->> 'yclients_id' = ?",
        external_id.to_s
      )
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def store_external_id(contact, external_id, company_id: nil, persist_with: :save!)
      return if contact.blank? || external_id.blank?

      additional_attributes = (contact.additional_attributes || {}).deep_dup
      additional_attributes['external'] ||= {}

      if company_id.present?
        additional_attributes['external']['yclients_ids'] ||= {}
        additional_attributes['external']['yclients_ids'][company_id.to_s] = external_id.to_s
      end

      company_mappings = normalized_company_ids(additional_attributes['external'])

      additional_attributes['external']['yclients_id'] = external_id.to_s if company_id.blank? || company_mappings.size <= 1

      persist_attributes(contact, additional_attributes, persist_with)
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    # rubocop:disable Metrics/CyclomaticComplexity
    def merge_company_attributes(contact, company_id:, attributes:, persist_with: :save!)
      return if contact.blank? || attributes.blank?

      additional_attributes = (contact.additional_attributes || {}).deep_dup
      additional_attributes['yclients'] = (additional_attributes['yclients'] || {}).merge(attributes)

      if company_id.present?
        additional_attributes['yclients_companies'] ||= {}
        additional_attributes['yclients_companies'][company_id.to_s] =
          (additional_attributes['yclients_companies'][company_id.to_s] || {}).merge(attributes)
      end

      persist_attributes(contact, additional_attributes, persist_with)
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    private

    def external_attributes(contact)
      contact&.additional_attributes&.fetch('external', {}) || {}
    end

    def normalized_company_ids(external_attributes)
      raw_ids = external_attributes['yclients_ids']
      return {} unless raw_ids.is_a?(Hash)

      raw_ids.transform_keys(&:to_s).transform_values(&:to_s).compact_blank
    end

    def persist_attributes(contact, additional_attributes, persist_with)
      case persist_with.to_sym
      when :update_columns
        contact.update!(additional_attributes: additional_attributes)
      else
        contact.additional_attributes = additional_attributes
        contact.public_send(persist_with)
      end
    end
  end
end
