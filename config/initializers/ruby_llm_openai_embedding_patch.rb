# frozen_string_literal: true

# Patch for RubyLLM's parse_embedding_response (OpenAI provider).
#
# Two failure modes when using a custom endpoint (e.g. OpenRouter):
#   1. Response body is a raw JSON String — Faraday's :json middleware only
#      parses when content-type is application/json; error responses often aren't.
#   2. API returns an error object (no "data" key) with HTTP 200, so RubyLLM's
#      ErrorMiddleware never raises, and data['data'].map crashes on nil.
#
# `super` is intentionally avoided: Embeddings uses module_function, which
# creates both private instance methods and singleton copies. Calling super
# from a prepended module causes the singleton copy to receive `response` as a
# positional String argument instead of a Faraday::Response, triggering
# "undefined method 'body' for an instance of String". We inline the three
# lines of original parsing logic to stay self-contained and predictable.
module RubyLLMOpenAIEmbeddingPatch
  def parse_embedding_response(response, model:, text:)
    body = extract_embedding_body(response)
    data_array = body.is_a?(Hash) && body['data']
    raise_embedding_error(body) unless data_array

    input_tokens = body.dig('usage', 'prompt_tokens') || 0
    vectors = data_array.map { |d| d['embedding'] } # rubocop:disable Rails/Pluck
    vectors = vectors.first if vectors.length == 1 && !text.is_a?(Array)
    RubyLLM::Embedding.new(vectors: vectors, model: model, input_tokens: input_tokens)
  end

  private

  def extract_embedding_body(response)
    body = response.respond_to?(:body) ? response.body : response
    body.is_a?(String) ? JSON.parse(body) : body
  end

  def raise_embedding_error(body)
    msg = body.is_a?(Hash) ? (body.dig('error', 'message') || body.inspect) : body.to_s
    raise RubyLLM::Error, "Embedding API error: #{msg}. Check CAPTAIN_OPEN_AI_ENDPOINT and API key."
  end
end

RubyLLM::Providers::OpenAI::Embeddings.prepend(RubyLLMOpenAIEmbeddingPatch)
