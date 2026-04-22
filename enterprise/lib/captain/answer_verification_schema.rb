class Captain::AnswerVerificationSchema < RubyLLM::Schema
  boolean :supported, description: 'True if every factual claim in the draft is supported by the provided sources'
  array :unsupported_claims, description: 'List of claims from the draft that are NOT supported by any source' do
    string description: 'A single unsupported claim, quoted or paraphrased from the draft'
  end
end
