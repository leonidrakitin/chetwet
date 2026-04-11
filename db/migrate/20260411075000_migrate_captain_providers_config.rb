class MigrateCaptainProvidersConfig < ActiveRecord::Migration[7.1]
  def up
    host = InstallationConfig.find_by(name: 'CAPTAIN_HOST')&.value
    api_key = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value

    deepseek_key = InstallationConfig.find_by(name: 'CAPTAIN_DEEPSEEK_API_KEY')&.value
    deepseek_endpoint = InstallationConfig.find_by(name: 'CAPTAIN_DEEPSEEK_ENDPOINT')&.value

    qwen_key = InstallationConfig.find_by(name: 'CAPTAIN_QWEN_API_KEY')&.value
    qwen_endpoint = InstallationConfig.find_by(name: 'CAPTAIN_QWEN_ENDPOINT')&.value

    ollama_endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OLLAMA_ENDPOINT')&.value
    ollama_key = InstallationConfig.find_by(name: 'CAPTAIN_OLLAMA_API_KEY')&.value

    openrouter_http_referer = InstallationConfig.find_by(name: 'CAPTAIN_OPENROUTER_HTTP_REFERER')&.value
    openrouter_title = InstallationConfig.find_by(name: 'CAPTAIN_OPENROUTER_TITLE')&.value

    embedding_key = InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_OPEN_AI_API_KEY')&.value
    embedding_endpoint = InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_OPEN_AI_ENDPOINT')&.value
    embedding_model = InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_MODEL')&.value

    primary = 'openai'
    primary = host if host.present? && %w[openrouter deepseek qwen ollama bigmodel.cn].include?(host)
    primary = 'zai' if host == 'bigmodel.cn'

    providers = {
      'openai' => {
        'enabled' => api_key.present?,
        'api_key' => api_key || '',
        'api_base' => endpoint || 'https://api.openai.com',
        'settings' => {}
      },
      'openrouter' => {
        'enabled' => host == 'openrouter' && api_key.present?,
        'api_key' => host == 'openrouter' ? api_key : '',
        'api_base' => 'https://openrouter.ai',
        'settings' => {
          'http_referer' => openrouter_http_referer || '',
          'title' => openrouter_title || ''
        }
      },
      'anthropic' => {
        'enabled' => false,
        'api_key' => '',
        'api_base' => 'https://api.anthropic.com',
        'settings' => {}
      },
      'gemini' => {
        'enabled' => false,
        'api_key' => '',
        'api_base' => 'https://generativelanguage.googleapis.com',
        'settings' => {}
      },
      'deepseek' => {
        'enabled' => deepseek_key.present?,
        'api_key' => deepseek_key || '',
        'api_base' => deepseek_endpoint || 'https://api.deepseek.com',
        'settings' => {}
      },
      'qwen' => {
        'enabled' => qwen_key.present?,
        'api_key' => qwen_key || '',
        'api_base' => qwen_endpoint || 'https://dashscope.aliyuncs.com/compatible-mode',
        'settings' => {}
      },
      'zai' => {
        'enabled' => host == 'bigmodel.cn' && api_key.present?,
        'api_key' => host == 'bigmodel.cn' ? api_key : '',
        'api_base' => 'https://open.bigmodel.cn',
        'settings' => {}
      },
      'ollama' => {
        'enabled' => ollama_endpoint.present?,
        'api_key' => ollama_key || '',
        'api_base' => ollama_endpoint || 'http://localhost:11434',
        'settings' => {}
      }
    }

    embedding = {
      'provider' => 'openai',
      'model' => embedding_model || 'text-embedding-3-small',
      'api_key' => embedding_key || '',
      'api_base' => embedding_endpoint || ''
    }

    fallback_order = []
    fallback_order << 'openai' if primary != 'openai' && providers['openai']['api_key'].present?

    config = {
      'primary_provider' => primary,
      'fallback_order' => fallback_order,
      'providers' => providers,
      'embedding' => embedding,
      'disabled_models' => []
    }

    existing = InstallationConfig.find_by(name: 'CAPTAIN_PROVIDERS')
    if existing
      existing.update!(value: config)
    else
      InstallationConfig.create!(name: 'CAPTAIN_PROVIDERS', value: config, locked: false)
    end
  end

  def down
    InstallationConfig.where(name: 'CAPTAIN_PROVIDERS').delete_all
  end
end
