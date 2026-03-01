# frozen_string_literal: true

# Patch for RubyLLM's parse_embedding_response (OpenAI provider).
# When using a custom endpoint (e.g. OpenRouter), the API may return an error
# object without a "data" key, or the response body may arrive as a raw JSON
# string (non-application/json content-type bypasses Faraday's :json parser).
# Both cases cause "undefined method 'map' for nil" on data['data'].map.
# We normalize the body and raise a descriptive error instead of crashing.
module RubyLLMOpenAIEmbeddingPatch
  def parse_embedding_response(response, model:, text:)
    body = response.body
    body = JSON.parse(body) if body.is_a?(String)

    data_array = body.is_a?(Hash) && body['data']
    unless data_array
      msg = body.is_a?(Hash) ? (body.dig('error', 'message') || body.inspect) : body.to_s
      raise RubyLLM::Error, "Embedding API error: #{msg}. Check CAPTAIN_OPEN_AI_ENDPOINT and API key."
    end

    super
  end
end

RubyLLM::Providers::OpenAI::Embeddings.prepend(RubyLLMOpenAIEmbeddingPatch)
