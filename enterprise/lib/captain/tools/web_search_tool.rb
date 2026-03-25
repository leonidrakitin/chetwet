class Captain::Tools::WebSearchTool < Captain::Tools::BasePublicTool
  description 'Search the web for current information, news, documentation, or any real-time data'
  param :query, type: 'string', desc: 'The search query'
  param :domain_filter, type: 'string', desc: 'Limit search to a specific domain (optional)', required: false
  param :recency, type: 'string', desc: 'Filter by recency: day, week, month (optional)', required: false

  MAX_RESULTS = 5

  def perform(_tool_context, query:, domain_filter: nil, recency: nil)
    log_tool_usage('web_search', { query: query, domain_filter: domain_filter, recency: recency })

    api_key = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value

    return 'Web search is not available: API not configured' if api_key.blank? || endpoint.blank?
    return 'Web search requires Z.AI endpoint' unless zai_endpoint?(endpoint)

    results = execute_search(api_key, endpoint, query, domain_filter, recency)
    format_search_results(results, query)
  rescue StandardError => e
    Rails.logger.error("WebSearchTool error: #{e.class} - #{e.message}")
    "Web search failed: #{e.message}"
  end

  private

  def zai_endpoint?(endpoint)
    endpoint.to_s.include?('z.ai')
  end

  def execute_search(api_key, endpoint, query, domain_filter, recency)
    base = endpoint.to_s.strip.chomp('/')
    url = URI("#{base}/chat/completions")

    tools = [build_web_search_tool(domain_filter, recency)]

    body = {
      model: 'glm-4.7',
      messages: [{ role: 'user', content: query }],
      tools: tools,
      tool_choice: { type: 'web_search' }
    }.to_json

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = url.scheme == 'https'
    http.read_timeout = 30
    http.open_timeout = 10

    request = Net::HTTP::Post.new(url.request_uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = body

    response = http.request(request)
    raise "Search API returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def build_web_search_tool(domain_filter, recency)
    tool = {
      type: 'web_search',
      web_search: {
        search_result: true
      }
    }
    tool[:web_search][:search_domain_filter] = domain_filter if domain_filter.present?
    tool[:web_search][:search_recency_filter] = recency if recency.present?
    tool
  end

  def format_search_results(response, query)
    content = response.dig('choices', 0, 'message', 'content')
    return "No results found for: #{query}" if content.blank?

    content.truncate(2000)
  end
end
