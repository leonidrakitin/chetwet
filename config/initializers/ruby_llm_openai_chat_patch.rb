# frozen_string_literal: true

# Patch: ruby_llm's parse_completion_response expects response.body to be a Hash.
# When body is a String (raw JSON), data.dig(...) raises NoMethodError.
# Wrap response so .body returns a parsed Hash when it was a String.
# The gem calls this as an instance method on RubyLLM::Providers::OpenAI, so we prepend there.
module RubyLLMParseCompletionResponsePatch
  ResponseBodyWrapper = Struct.new(:body, :_response) do
    def method_missing(m, *a, **k)
      _response.public_send(m, *a, **k)
    end

    def respond_to_missing?(m, *)
      _response.respond_to?(m)
    end
  end

  def parse_completion_response(response)
    body = response.body
    if body.is_a?(String)
      return if body.empty?

      stripped = body.strip
      unless stripped.start_with?('{', '[')
        raise RubyLLM::Error.new(response,
          'API returned non-JSON (HTML or redirect). Check CAPTAIN_OPEN_AI_ENDPOINT and API key.')
      end
      begin
        body = JSON.parse(body)
      rescue JSON::ParserError
        raise RubyLLM::Error.new(response,
          'API returned invalid JSON. Check CAPTAIN_OPEN_AI_ENDPOINT and API key.')
      end
    end
    return if body.blank?

    super(ResponseBodyWrapper.new(body, response))
  end
end

RubyLLM::Providers::OpenAI.prepend(RubyLLMParseCompletionResponsePatch)
