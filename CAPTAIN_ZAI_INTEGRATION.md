# Z.AI Integration for Chatwoot Captain

## Overview

Complete integration of Z.AI (GLM-5, GLM-4.6V, GLM-OCR, GLM-ASR) into Chatwoot's Captain AI system. Enables advanced conversational AI with vision, multimodal, and specialized model support.

## Architecture

```
┌─────────────────────────────────────────────┐
│      Chatwoot Captain AI System             │
├─────────────────────────────────────────────┤
│  - Agent Runner (Agents SDK)                │
│  - Tool Functions (Web Search, Get Contact) │
│  - Response Builder (Streaming)             │
│  - Message Builder (Multimodal support)     │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│    Z.AI Service Layer                       │
├─────────────────────────────────────────────┤
│  Services:                                  │
│  • VisionService (GLM-4.6V image analysis)  │
│  • OcrService (GLM-OCR text extraction)     │
│  • AudioTranscriptionService (GLM-ASR)      │
│  • AutoClassificationService (GLM-5)        │
│  • PerformanceMonitoringService (OpenTel)   │
│                                             │
│  Feature Flags:                             │
│  • ZAI_PROVIDER_ENABLED                     │
│  • ZAI_ROLLOUT_PERCENTAGE                   │
│  • ZAI_VISION_ENABLED                       │
│  • ZAI_THINKING_MODE_ENABLED                │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│    Z.AI API (https://api.z.ai/...)          │
├─────────────────────────────────────────────┤
│  Models:                                    │
│  • glm-5 (flagship, reasoning)              │
│  • glm-4.6 (premium, vision-capable)        │
│  • glm-4.6v (vision specialist)             │
│  • glm-ocr (text extraction from images)    │
│  • glm-asr-2512 (audio transcription)       │
└─────────────────────────────────────────────┘
```

## Setup Instructions

### 1. Configuration

Set via Super Admin Console → Settings:

```
CAPTAIN_OPEN_AI_ENDPOINT = https://api.z.ai/api/paas/v4
CAPTAIN_OPEN_AI_API_KEY = <Z.AI API key>
CAPTAIN_OPEN_AI_MODEL = glm-5 (default)
CAPTAIN_ZAI_PROVIDER_ENABLED = true
```

### 2. Feature Flag Setup

```ruby
# Enable Z.AI globally
Captain::FeatureFlagsHelper.enable_zai_provider!

# Start with 10% rollout
Captain::FeatureFlagsHelper.set_rollout_percentage(10)
```

### 3. Test Integration

```ruby
# In Rails console:
bundle exec rails console

# Test basic connectivity
Llm::Config.with_api_key('your-z-ai-key') do
  chat = RubyLLM::Chat.with_model('glm-5')
  response = chat.prompt("Say hello")
  puts response.output
end
```

## Feature Documentation

### Vision Processing (GLM-4.6V)

Automatically activated when:
- Message contains image attachments
- Current model is GLM-5 (non-vision model)

```ruby
# Manual usage:
vision_service = Captain::Llm::VisionService.new(message_content)
analyzed = vision_service.process
```

### OCR & Document Processing (GLM-OCR)

```ruby
# Extract text from screenshots:
ocr_service = Captain::Llm::OcrService.new('https://example.com/image.png')
text = ocr_service.extract_text
```

### Audio Transcription (GLM-ASR-2512)

Replaces Whisper when Z.AI is configured:

```ruby
# Manual transcription:
audio_service = Captain::Llm::AudioTranscriptionService.new(attachment)
result = audio_service.perform
# => { success: true, transcriptions: "..." }
```

### Thinking Mode (GLM-5 Reasoning)

Displays LLM's reasoning process in Copilot UI:

- Creates collapsible "Show Reasoning" block
- Stores reasoning_content from Z.AI response
- Tracks reasoning tokens for cost analysis

### Auto-Classification (Structured Output)

Automatically classify new conversations:

```ruby
# Manual classification:
classifier = Captain::AutoClassificationService.new(
  conversation: conversation,
  assistant: assistant
)
result = classifier.classify
# => { department: 'support', priority: 'high', sentiment: 'negative', ... }

# Async via job:
Captain::AutoClassifyConversationJob.perform_later(
  conversation_id: conversation.id
)
```

Returns:
- `department` - Routing suggestion (sales, support, billing, technical, general)
- `priority` - Urgency (low, medium, high, urgent)
- `sentiment` - Customer mood (negative, neutral, positive)
- `language` - Detected language
- `tags` - Categorization tags
- `requires_immediate_response` - Boolean flag

## Tool Integration

### Built-in Tools

1. **Search Conversations**
   - Query conversations by text, status, labels
   - Returns summary with contact and last activity

2. **Get Contact Profile**
   - Full contact details with conversation history
   - Custom attributes and engagement summary

3. **Web Search**
   - Real-time web search when FAQ insufficient
   - Returns up to 2000 chars of relevant results

### Custom Tools

Z.AI supports both standard OpenAI-format tools and specialized functions.

## Deployment Strategy

### Rollout Phases

| Stage | Percentage | Duration | Actions |
|-------|-----------|----------|---------|
| Testing | 0% | 2-3 days | Internal validation |
| Early Access | 10% | 3-5 days | Trusted customers, monitoring |
| Beta | 25% | 5-7 days | Wider testing, performance check |
| Staging | 50% | 3-5 days | Pre-GA preparation |
| General | 100% | Ongoing | Full release |

### Monitoring

Track via OpenTelemetry traces in Langfuse:

```ruby
# View performance:
analytics = Captain::PerformanceAnalyticsService.new(
  account_id: account.id,
  time_range: 24.hours.ago..Time.current
)

puts analytics.analytics
# => { total_requests: 1250, average_latency_ms: 850, tokens_used: {...}, ... }
```

### Rollback Plan

If issues detected:

```ruby
# Immediately disable:
Captain::FeatureFlagsHelper.disable_zai_provider!

# Or reduce rollout percentage:
Captain::FeatureFlagsHelper.set_rollout_percentage(5)

# System automatically falls back to default model
```

## Performance Metrics

Tracked automatically in OpenTelemetry:

- **Input/Output Tokens** - Usage tracking
- **Cache Tokens** - Cache effectiveness (Z.AI Context Caching)
- **Reasoning Tokens** - Thinking Mode cost
- **Model Family/Tier** - Cost allocation
- **Latency** - Response times
- **Error Rate** - Reliability tracking

## Troubleshooting

### 1. "Z.AI credentials not configured"

```ruby
# Verify setup:
Llm::Config.load_api_key_for_provider('zai')
Llm::Config.load_endpoint_for_provider('zai')

# Check Installation configs:
InstallationConfig.where(name: %w[
  CAPTAIN_OPEN_AI_API_KEY
  CAPTAIN_OPEN_AI_ENDPOINT
]).each { |c| puts "#{c.name} = #{c.value}" }
```

### 2. Invalid endpoint URL

Endpoint normalization is automatic:
- `https://api.z.ai/api/paas/v4` → `https://api.z.ai/api/paas/v4`
- `/v1` appended only if missing version suffix

### 3. Image processing fails

Ensure:
- Image URL is publicly accessible
- Content-Type header is correct
- Image size < API limits

### 4. Streaming stops unexpectedly

Check:
- ActionCable WebSocket connection
- Browser console for errors
- Response Builder Job logs

## Testing

Run E2E integration tests:

```bash
bundle exec rspec spec/enterprise/services/captain/integration_spec.rb
```

Covers:
1. Basic chat completion
2. Streaming responses
3. Function calling
4. Vision processing
5. Thinking Mode
6. Web Search
7. OCR/Document processing
8. Model fallback
9. Auto-classification
10. Performance monitoring

## Cost Tracking

Token usage tracked in conversation metadata:

```ruby
conversation.additional_attributes['auto_classification']
# => {
#   department: 'support',
#   priority: 'high',
#   sentiment: 'negative',
#   language: 'en',
#   requires_immediate_response: true,
#   suggested_template: 'faq_1',
#   classified_at: '2025-01-15T10:30:00Z'
# }
```

## Architecture Files

- **Config**: `lib/llm/config.rb`
- **Message Building**: `enterprise/app/services/captain/open_ai_message_builder_service.rb`
- **Vision**: `enterprise/app/services/captain/llm/vision_service.rb`
- **OCR**: `enterprise/app/services/captain/llm/ocr_service.rb`
- **Audio**: `enterprise/app/services/captain/llm/audio_transcription_service.rb`
- **Classification**: `enterprise/app/services/captain/auto_classification_service.rb`
- **Monitoring**: `enterprise/app/services/captain/performance_monitoring_service.rb`
- **Feature Flags**: `enterprise/app/services/captain/feature_flags_helper.rb`
- **Tools**: `enterprise/lib/captain/tools/`
- **Copilot UI**: `app/javascript/dashboard/components-next/copilot/`

## Support & Documentation

- Z.AI Docs: https://docs.z.ai/
- RubyLLM: https://github.com/openai/ruby-sdk
- Agents SDK: Built-in to Chatwoot
- Issues: GitHub Issues in Chatwoot repo

---

**Last Updated**: 2025-01-15
**Status**: Production Ready
**Tested with**: Z.AI GLM-5 API, RubyLLM v1.9.2, Agents SDK
