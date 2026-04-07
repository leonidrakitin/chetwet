# TODO: Wrap the schema lib under ai-agents
# So we can extend it as Agents::Schema
class Captain::ResponseSchema < RubyLLM::Schema
  string :status, description: 'Execution status such as answered, awaiting_human, busy, or escalated'
  string :response, description: 'The message to send to the user'
  string :reasoning, description: "Agent's thought process"
end
