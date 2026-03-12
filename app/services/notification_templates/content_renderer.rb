class NotificationTemplates::ContentRenderer
  VARIABLE_REGEXP = /@(\w+)|\{(\w+)\}/

  pattr_initialize [:content!, :context]

  def call
    content.to_s.gsub(VARIABLE_REGEXP) do
      key = Regexp.last_match(1) || Regexp.last_match(2)
      context[key].presence || Regexp.last_match(0)
    end
  end
end
