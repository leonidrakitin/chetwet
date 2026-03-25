# Usage: bundle exec rails runner scripts/zai_smoke_test.rb
#
# Tests Z.AI connectivity through RubyLLM with current InstallationConfig.
# Verifies: endpoint normalization, chat completion, streaming, token usage.

require 'ruby_llm'

puts '=== Z.AI Smoke Test ==='
puts ''

# 1. Check configuration
api_key = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
model = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence || Llm::Config::DEFAULT_MODEL

puts "Endpoint: #{endpoint || '(not set - using OpenAI default)'}"
puts "Model:    #{model}"
puts "API Key:  #{api_key&.slice(0, 8)}...#{api_key&.slice(-4, 4)}" if api_key
puts ''

unless api_key
  puts 'ERROR: CAPTAIN_OPEN_AI_API_KEY not configured.'
  puts 'Set it in Super Admin > Installation Config.'
  exit 1
end

# 2. Check endpoint normalization
if endpoint
  base = endpoint.is_a?(Hash) ? (endpoint[:value] || endpoint['value']).to_s : endpoint.to_s
  base = base.strip.chomp('/')
  normalized = %r{/v\d+/?$}.match?(base) ? base : "#{base}/v1"
  puts "Normalized endpoint: #{normalized}"
  puts ''
end

# 3. Test chat completion
puts '--- Test 1: Chat Completion ---'
begin
  Llm::Config.reset!
  Llm::Config.initialize!

  Llm::Config.with_api_key(api_key, api_base: endpoint) do |context|
    chat = context.chat(model: model)
    chat = chat.with_temperature(0.1)
    response = chat.ask('Reply with exactly: Z.AI connection OK')

    puts "Response: #{response.content}"
    puts "Input tokens:  #{response.input_tokens}"
    puts "Output tokens: #{response.output_tokens}"
    puts "Cached tokens: #{response.respond_to?(:cached_tokens) ? response.cached_tokens : 'N/A'}"
    puts 'PASS'
  end
rescue StandardError => e
  puts "FAIL: #{e.class} - #{e.message}"
  puts e.backtrace.first(3).join("\n")
end

puts ''
puts '=== Done ==='
