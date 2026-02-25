# Trace: Playground input → extract_text_and_attachments (and where the error happens)

## 1. Frontend: Playground UI

**File:** `app/javascript/dashboard/components-next/captain/assistant/AssistantPlayground.vue`

- User types in `newMessage` (e.g. `"sadas"`).
- On submit, `sendMessage()`:
  - Pushes `{ content: newMessage.value, sender: 'user', ... }` to `messages.value`.
  - Calls `CaptainAssistant.playground({ assistantId, messageContent: currentMessage, messageHistory: formatMessagesForApi() })`.

**`formatMessagesForApi()`** (lines 19–24):

```js
return messages.value.map(message => ({
  role: message.sender,
  content: message.content,
}));
```

- First send: `message_history: [{ role: 'user', content: 'sadas' }]` → **content is a string**.
- After first reply: assistant message is pushed with `content: data.response` (string from API). So on second send, history still has **string** `content` for both user and assistant.

So from the **playground UI alone**, `content` is always a **string**. The error does not happen on this path unless the client or backend later turns content into an array.

---

## 2. API request

**File:** `app/javascript/dashboard/api/captain/assistant.js`

```js
playground({ assistantId, messageContent, messageHistory }) {
  return axios.post(`${this.url}/${assistantId}/playground`, {
    message_content: messageContent,
    message_history: messageHistory,
  });
}
```

- Body: `{ message_content: "sadas", message_history: [{ role: "user", content: "sadas" }] }`.
- No `assistant` wrapper in this client. Controller uses `params.require(:assistant).permit(...)` for `playground_params`, so either the real frontend wraps the payload in `assistant` or the controller expects a different param shape elsewhere.

---

## 3. Controller

**File:** `enterprise/app/controllers/api/v1/accounts/captain/assistants_controller.rb`

- **`playground`** (lines 26–32): calls  
  `Captain::Llm::AssistantChatService.new(assistant: @assistant).generate_response(additional_message: params[:message_content], message_history: message_history)`  
  and `render json: response`.
- **`message_history`** (lines 69–71):  
  `(playground_params[:message_history] || []).map { |message| { role: message[:role], content: message[:content] } }`.

So each element passed to the service is `{ role:, content: }`. For the playground client above, `content` is the string from the request (e.g. `"sadas"`).

---

## 4. AssistantChatService

**File:** `enterprise/app/services/captain/llm/assistant_chat_service.rb`

- **`generate_response(additional_message:, message_history:, role: 'user')`** (lines 21–24):
  - `@messages += message_history`
  - `@messages << { role: role, content: additional_message }` if `additional_message.present?`
  - then `request_chat_completion`.

So `@messages` = system message + `message_history` (each with `content` as passed from the controller) + optional current user message. For the playground, every `content` here is still a **string**.

---

## 5. ChatHelper: where extract_text_and_attachments is called

**File:** `enterprise/app/helpers/captain/chat_helper.rb`

Two call sites:

**A) Last message (for `chat.ask`)** — lines 13–16:

```ruby
last_content = conversation_messages.last[:content]
text, attachments = Captain::OpenAiMessageBuilderService.extract_text_and_attachments(last_content)
response = attachments.any? ? chat.ask(text, with: attachments) : chat.ask(text)
```

**B) History (for `add_messages_to_chat`)** — lines 71–75:

```ruby
conversation_messages[0...-1].each do |msg|
  text, attachments = Captain::OpenAiMessageBuilderService.extract_text_and_attachments(msg[:content])
  content = attachments.any? ? RubyLLM::Content.new(text, attachments) : text
  chat.add_message(role: msg[:role].to_sym, content: content)
end
```

- **`conversation_messages`** = `@messages.reject { |m| m[:role] == 'system' || m[:role] == :system }` (same `content` values as above).

So for **playground-only** usage, both `last_content` and each `msg[:content]` are **strings** → `extract_text_and_attachments` returns `[content, []]` and never runs the array branch where the error can occur.

---

## 6. When does `content` become an Array? (Path that leads to the error)

It becomes an **array** when `message_history` is built from **real conversation messages** that use multimodal content.

**File:** `enterprise/app/jobs/captain/conversation/response_builder_job.rb`

- **`generate_and_process_response`** (v1) or **`generate_response_with_v2`** call the assistant with  
  `message_history: collect_previous_messages`.
- **`collect_previous_messages`** (lines 55–70):

  ```ruby
  @conversation.messages
    .where(message_type: [:incoming, :outgoing])
    .where(private: false)
    .map do |message|
      message_hash = {
        content: prepare_multimodal_message_content(message),
        role: determine_role(message)
      }
      # ...
    end
  ```

- **`prepare_multimodal_message_content(message)`** (lines 76–78):

  ```ruby
  Captain::OpenAiMessageBuilderService.new(message: message).generate_content
  ```

**File:** `enterprise/app/services/captain/open_ai_message_builder_service.rb` — **`generate_content`** (lines 13–22):

- Builds `parts` (text + attachment parts).
- If there are multiple parts or an image part, it returns **`parts`** (an array), e.g.  
  `[{ type: 'text', text: '...' }, { type: 'image_url', image_url: { url: '...' } }]`.
- So for conversations with attachments, **`msg[:content]` in message_history is an Array**.

That array is then passed into **`extract_text_and_attachments`** in the same ChatHelper flow (either as `last_content` or as `msg[:content]` in `add_messages_to_chat`).

---

## 7. The error in extract_text_and_attachments

**File:** `enterprise/app/services/captain/open_ai_message_builder_service.rb` (lines 5–11)

```ruby
def self.extract_text_and_attachments(content)
  return [content, []] unless content.is_a?(Array)

  text_parts = content.select { |part| part[:type] == 'text' }.pluck(:text)
  image_urls = content.select { |part| part[:type] == 'image_url' }.filter_map { |part| part.dig(:image_url, :url) }
  [text_parts.join(' ').presence, image_urls]
end
```

- When `content` is an **array** (from the conversation job path above), we enter the second and third lines.
- For a part with `type == 'image_url'`, the code does **`part.dig(:image_url, :url)`**.
- If `part[:image_url]` is a **String** (e.g. a raw URL from another client or old format) instead of `{ url: "..." }`, then `part.dig(:image_url, :url)` effectively does `"https://...".dig(:url)` → **`undefined method 'dig' for an instance of String`**.

So the error happens when:

1. **message_history** contains at least one message whose **content** is an **array** (multimodal), and  
2. That array has a part with `type == 'image_url'` and **`image_url` is a String** (not a Hash with `:url`).

---

## 8. Summary table

| Source of message_history | content shape       | extract_text_and_attachments | Error? |
|---------------------------|---------------------|-----------------------------|--------|
| Playground (AssistantPlayground.vue) | string              | `return [content, []]`      | No     |
| Conversation job (ResponseBuilderJob + collect_previous_messages) | array (from generate_content) | Array branch, line 9        | Yes if any part has `image_url` as String |

So:

- **Pure playground** (only text, first or later turns): content stays string → no error.
- **Conversation with messages that have attachments**: history is built with `generate_content` → content is array → if any image part has string `image_url`, line 9 raises.

If you see the error while testing “in the playground”, it can be because:

1. The same backend/service is used from the **conversation job** (e.g. you sent a message in a conversation that had an image), or  
2. Some client or proxy sends **message_history** with array/multimodal `content` to the playground endpoint.

**Fix:** In `extract_text_and_attachments`, treat both `image_url` as Hash and as String (e.g. `url = part[:image_url]; url = url.is_a?(Hash) ? url[:url] : url`) so `.dig` is never called on a String.
