# Business Context & Captain Copilot Integration Plan

## Status: COMPLETED ✅

## Overview

Add business context collection during onboarding and use it in Captain Copilot for:

1. Contextualizing responses
2. Interactive assistant configuration from templates
3. Adapting FAQs and scenarios to business realities

## Implemented Changes

### Backend (Rails)

| File                                                                                   | Change                                                         |
| -------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `app/models/account.rb`                                                                | Added `store_accessor :business_context` and validation schema |
| `app/controllers/api/v1/accounts_controller.rb`                                        | Added `business_context` to permitted settings params          |
| `config/locales/en.yml`                                                                | Added business context examples (en/ru)                        |
| `config/routes.rb`                                                                     | Added `adapt` and `clarifying_questions` endpoints             |
| `enterprise/app/services/captain/llm/system_prompts_service.rb`                        | Added `[Business Context]` section to copilot prompt           |
| `enterprise/app/services/captain/copilot/chat_service.rb`                              | Pass business_context to system prompt                         |
| `enterprise/app/services/captain/assistant_templates/template_adapter_service.rb`      | NEW: LLM-based template adaptation                             |
| `enterprise/app/services/captain/assistant_templates/instantiator.rb`                  | Added `adapted_data` parameter support                         |
| `enterprise/app/controllers/api/v1/accounts/captain/assistant_templates_controller.rb` | Added `adapt` and `clarifying_questions` actions               |
| `enterprise/app/services/captain/tools/copilot/configure_assistant_service.rb`         | NEW: Copilot tool for assistant configuration                  |
| `enterprise/app/services/captain/tools/copilot/suggest_faqs_service.rb`                | NEW: FAQ suggestions based on business context                 |
| `enterprise/app/services/captain/tools/copilot/adapt_faq_service.rb`                   | NEW: FAQ adaptation tool                                       |
| `enterprise/app/services/captain/tools/copilot/adapt_scenario_service.rb`              | NEW: Scenario adaptation tool                                  |

### Frontend (Vue)

| File                                                                                                | Change                                                 |
| --------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| `app/javascript/v3/views/onboarding/steps/BusinessContextStep.vue`                                  | NEW: Onboarding step for business context              |
| `app/javascript/v3/views/onboarding/steps/UseCaseStep.vue`                                          | Modified: Added `update` emit for wizard integration   |
| `app/javascript/v3/views/onboarding/OnboardingWizard.vue`                                           | Added BusinessContextStep, businessContext persistence |
| `app/javascript/dashboard/routes/dashboard/settings/account/components/BusinessContextSettings.vue` | NEW: Settings component                                |
| `app/javascript/dashboard/routes/dashboard/settings/account/Index.vue`                              | Integrated BusinessContextSettings component           |
| `app/javascript/dashboard/i18n/locale/en/signup.json`                                               | Added onboarding i18n keys                             |
| `app/javascript/dashboard/i18n/locale/en/generalSettings.json`                                      | Added settings i18n keys                               |

### Templates (YAML)

| File                                                       | Change                               |
| ---------------------------------------------------------- | ------------------------------------ |
| `config/captain/assistant_templates/beauty_salon.yml`      | Added `clarifying_questions` section |
| `config/captain/assistant_templates/hr_recruiter.yml`      | Added `clarifying_questions` section |
| `config/captain/assistant_templates/restaurant_dinein.yml` | Added `clarifying_questions` section |

## Architecture

```
ONBOARDING                    CAPTAIN COPILOT
┌─────────────────┐          ┌─────────────────────────────────────┐
│ BusinessContext │ ───────► │ Analyze business_context            │
│ Step            │          │                                     │
│ - business_type │          │ ├─► Suggest assistant from template │
│ - description   │          │ │                                   │
└─────────────────┘          │ ├─► Ask clarifying questions        │
                             │ │   (from template definition)       │
                             │ │                                   │
                             │ └─► Adapt template:                 │
                             │     - Scenarios (instructions)      │
                             │     - FAQs (questions/answers)      │
                             │     - Response guidelines           │
                             └─────────────────────────────────────┘
```

## Data Structure

### Account.settings['business_context']

```json
{
  "business_type": "support|sales|feedback|internal|ecommerce|other",
  "description": "Brief description (max 200 chars)"
}
```

## Implementation Phases

### Phase 1: Backend - Storage & API

- [x] Add `business_context` to Account.settings
- [ ] Update SETTINGS_PARAMS_SCHEMA for validation
- [ ] Update accounts_controller permitted params
- [ ] Add i18n examples (en/ru)

### Phase 2: Frontend - Onboarding

- [ ] Create BusinessContextStep.vue
- [ ] Modify OnboardingWizard.vue
- [ ] Modify UseCaseStep.vue
- [ ] Add i18n keys

### Phase 3: Frontend - Settings

- [ ] Create BusinessContextSettings.vue
- [ ] Integrate into Index.vue
- [ ] Add i18n keys

### Phase 4: Copilot Integration

- [ ] Update system_prompts_service.rb
- [ ] Update chat_service.rb
- [ ] Create TemplateAdapterService
- [ ] Create ConfigureAssistantService tool
- [ ] Create SuggestFaqsService tool
- [ ] Create AdaptFaqService tool
- [ ] Create AdaptScenarioService tool
- [ ] Add clarifying questions to YAML templates
- [ ] Modify Instantiator for adapted_data
- [ ] Add API endpoint for template adaptation

## Files to Create/Modify

### CREATE

1. `app/javascript/v3/views/onboarding/steps/BusinessContextStep.vue`
2. `app/javascript/dashboard/routes/dashboard/settings/account/components/BusinessContextSettings.vue`
3. `enterprise/app/services/captain/assistant_templates/template_adapter_service.rb`
4. `enterprise/app/services/captain/tools/copilot/configure_assistant_service.rb`
5. `enterprise/app/services/captain/tools/copilot/suggest_faqs_service.rb`
6. `enterprise/app/services/captain/tools/copilot/adapt_faq_service.rb`
7. `enterprise/app/services/captain/tools/copilot/adapt_scenario_service.rb`

### MODIFY

1. `app/models/account.rb` - add business_context store_accessor
2. `app/controllers/api/v1/accounts_controller.rb` - add to permitted params
3. `app/javascript/v3/views/onboarding/OnboardingWizard.vue`
4. `app/javascript/v3/views/onboarding/steps/UseCaseStep.vue`
5. `app/javascript/dashboard/routes/dashboard/settings/account/Index.vue`
6. `enterprise/app/services/captain/llm/system_prompts_service.rb`
7. `enterprise/app/services/captain/copilot/chat_service.rb`
8. `enterprise/app/services/captain/assistant_templates/instantiator.rb`
9. `enterprise/app/controllers/api/v1/accounts/captain/assistant_templates_controller.rb`
10. `config/captain/assistant_templates/*.yml` - add clarifying_questions
11. i18n files

## Clarifying Questions Per Template

Templates will include predefined questions that LLM will ask during setup:

```yaml
clarifying_questions:
  - question_i18n:
      en: 'What products or services do you offer?'
      ru: 'Какие продукты или услуги вы предлагаете?'
    purpose: 'product_info'
  - question_i18n:
      en: 'What are the most common customer questions?'
      ru: 'Какие вопросы клиенты задают чаще всего?'
    purpose: 'faq_hints'
  - question_i18n:
      en: 'Do you have any special policies (returns, SLA, etc.)?'
      ru: 'Есть ли особые политики (возвраты, SLA и т.д.)?'
    purpose: 'policies'
```

## Business Type Examples (i18n)

### en.yml

```yaml
business_context:
  examples:
    support:
      en: 'We provide 24/7 technical support for our SaaS project management platform.'
      ru: 'Мы предоставляем круглосуточную техподдержку для SaaS-платформы управления проектами.'
    sales:
      en: 'We are a B2B sales platform helping companies find and close leads.'
      ru: 'Мы B2B платформа продаж, помогающая компаниям находить и закрывать сделки.'
    feedback:
      en: 'We collect and analyze customer feedback for product improvement.'
      ru: 'Мы собираем и анализируем отзывы клиентов для улучшения продукта.'
    internal:
      en: 'We use this for internal team communication and coordination.'
      ru: 'Мы используем это для внутренней коммуникации и координации команды.'
    ecommerce:
      en: 'We are an online store selling handmade jewelry worldwide.'
      ru: 'Мы интернет-магазин авторских украшений с доставкой по всему миру.'
    other:
      en: 'We help businesses automate their customer communication.'
      ru: 'Мы помогаем бизнесу автоматизировать общение с клиентами.'
```
