# TODO: Wrap the schema lib under ai-agents
# So we can extend it as Agents::Schema
class Captain::ResponseSchema < RubyLLM::Schema
  string :status,
         description: 'Execution status: "answered" when replying, "awaiting_human" when escalating via escalate_to_human tool, or "clarification" when asking the user a question'
  string :response, description: 'The message to send to the user'
  string :reasoning, description: "Agent's thought process"
end
