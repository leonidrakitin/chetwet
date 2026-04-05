# frozen_string_literal: true

# OpenRouter recommends HTTP-Referer and X-OpenRouter-Title on API requests.
# ruby_llm's OpenAI provider only sends Authorization; merge these when the base URL is OpenRouter.
module RubyLLMOpenRouterHeadersPatch
  def headers
    base = super
    return base unless openrouter_endpoint?

    base.merge(
      'HTTP-Referer' => openrouter_http_referer,
      'X-OpenRouter-Title' => openrouter_app_title
    )
  end

  private

  def openrouter_endpoint?
    api_base.to_s.include?('openrouter.ai')
  end

  def openrouter_http_referer
    InstallationConfig.find_by(name: 'CAPTAIN_OPENROUTER_HTTP_REFERER')&.value.presence ||
      InstallationConfig.find_by(name: 'BRAND_URL')&.value.presence ||
      'https://github.com/chatwoot/chatwoot'
  end

  def openrouter_app_title
    InstallationConfig.find_by(name: 'CAPTAIN_OPENROUTER_TITLE')&.value.presence ||
      InstallationConfig.find_by(name: 'INSTALLATION_NAME')&.value.presence ||
      'Chatwoot'
  end
end

RubyLLM::Providers::OpenAI.prepend(RubyLLMOpenRouterHeadersPatch)
