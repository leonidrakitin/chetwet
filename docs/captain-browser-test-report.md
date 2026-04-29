# Captain Browser Test Report

Date: 2026-04-27
Environment: `https://estbot.ru`, account `1`, target conversation `2`
Tester: AI agent (browser MCP) + pending customer-side input

## Stage 1 - Assistant setup/data preparation

Status: Completed

### Verified

- Captain settings page is accessible at `https://estbot.ru/app/accounts/1/captain/1/settings`.
- Active assistant: `Администратор салона`.
- Knowledge mode: `Очень строго` (ultra strict).
- Enabled feature toggles seen:
  - memory on
  - source citations on
  - contact attributes on
- Core tools section expanded and confirmed enabled:
  - `faq_lookup`
  - `handoff`
  - `resolve_conversation`
  - `confirm_with_customer`
  - `notify_staff`
  - `schedule_follow_up`
  - `get_contact_memory`
  - `update_contact_memory`
  - plus notes/labels/priority/search/contact/web_search

### Notes

- UI appears mobile-like and some sidebar refs are not directly clickable by automation due to off-screen positioning.
- Route `.../captain/1/marketplace` redirected to dashboard in this session.

## Stage 2 - Dialog test execution

Status: Blocked for fully autonomous run; can proceed in assisted mode.

### Blocker

- In operator UI conversation view, outgoing editor is read-only, so the agent cannot inject incoming customer messages from this screen.
- To test autonomous Captain behavior end-to-end, one side must send real inbound customer messages (widget/channel side or API).

### Assisted test script (customer messages to send)

Send these messages as customer in conversation `#2`, one by one. Wait for assistant response after each.

1. `Привет! Есть ли бесплатная парковка?`
  - Expectation: FAQ-based answer with strict behavior (or escalation if no confident match).
2. `Ок, а можешь напомнить мне через 3 минуты, чтобы я подтвердил запись?`
  - Expectation: assistant confirms delayed follow-up is scheduled.
  - Backend expectation: `schedule_follow_up` tool path should create scheduled delivery.
3. Wait 4-5 minutes without new customer messages.
  - Expectation: delayed follow-up message is actually delivered to same conversation.
4. `Я хочу, чтобы меня переключили на человека`
  - Expectation: human handoff intent recognized and handoff message appears.
5. `Запомни: я предпочитаю утренние слоты`
  - Expectation: memory update may happen; later responses should reflect preference.
6. `Какие у вас правила после процедуры?`
  - Expectation: FAQ retrieval with strict mode behavior and source-grounded answer.

### Execution log (live)

- 16:39 customer message received in conversation `#2`:
  - `Привет! Есть ли бесплатная парковка?`
- Observed assistant/system response:
  - `Передача другому агенту для дальнейшей помощи.`
- Immediate interpretation:
  - FAQ answer was not produced.
  - Conversation escalated/handoff instead of direct strict FAQ response.
  - This is acceptable only if strict policy intentionally requires escalation for this prompt; otherwise this is a quality gap for known FAQ questions.
- 16:41 customer message received in conversation `#2`:
  - `Ок, тогда напомни мне через 3 минуты подтвердить запись.`
- Observed assistant/system response:
  - `Передача другому агенту для дальнейшей помощи.`
- Immediate interpretation:
  - `schedule_follow_up` was not reached from this path.
  - Delayed-delivery scenario is blocked because assistant escalates before tool execution.
  - Need to first stabilize direct-response mode (or use a scenario that has follow-up tool and does not immediately escalate).
- 16:46 customer message received after switching knowledge mode to `Сбалансированно`:
  - `Напомни мне через 3 минуты подтвердить запись.`
- Observed assistant/system response:
  - no assistant text response yet in observed window (message remains pending without tool-visible confirmation)
  - previous pattern remains escalation-prone for similar prompts
- Immediate interpretation:
  - knowledge mode change alone did not immediately unlock delayed-follow-up flow in this conversation.
  - move to plan B: configure/activate explicit scenario path for reminder handling with `schedule_follow_up` and retest.

### Additional integration checks to run after core flow

- Ask for action requiring `confirm_with_customer` and verify yes/no gating:
  - `Запиши меня на завтра на 10:00`
  - then respond `да` or `нет` to confirmation question.
- Ask for staff notify path:
  - `Позови администратора, пусть свяжется со мной`

## Stage 3 - Analysis summary (preliminary)

### What is already clear

- Configuration for autonomous tooling is present and includes delayed-send tool.
- Knowledge strictness was changed from `Очень строго` to `Сбалансированно` during test run (attempt to reduce immediate escalations).

### Log-based root cause evidence (critical)

- For message `Напомни мне через 3 минуты подтвердить запись.` webhook event arrived, but job log shows:
  - `[VK] Duplicate event skipped for group_id=225520986 type=message_new event_id=13e72297dbba333542aaea48c3e37fd405008b79`
- This means inbound event processing was short-circuited as duplicate at webhook-job layer.
- Consequence:
  - no fresh assistant run for that turn
  - no `schedule_follow_up` tool execution
  - no ad-hoc `NotificationTemplateDelivery` scheduled from Captain path
- Supporting symptom from runtime payload in logs:
  - `assistant_runtime.last_run_completed_at` remained old (`2026-04-27T13:41:40Z`) while new customer message existed.
- `NotificationTemplates::ProcessScheduledJob` did run on schedule, but this alone is not enough:
  - if no `scheduled` delivery exists, there is nothing to dispatch.
- Major limitation for browser-only autonomous testing is lack of customer-side message injection from operator screen.

### New blocker confirmed from latest run

- New run with scenario enabled still ended in immediate handoff.
- ResponseBuilder job logs include:
  - `[Captain V2][LLM] Provider configuration error on attempt 0 ... RubyLLM::ConfigurationError: Missing configuration for OpenAI: openai_api_key`
- This is currently the primary blocker for Captain V2 behavior:
  - primary provider is not effectively configured for runtime
  - scenario instructions are not reliably evaluated
  - tool invocation (`schedule_follow_up`) cannot start
  - autonomy policy retries and then escalates to handoff
- Practical implication:
  - until primary provider configuration is fixed in Super Admin `CAPTAIN_PROVIDERS`, tests G1-G6 (delayed send) and tool/integration matrix results are invalid as product-behavior evidence, because execution fails before business logic.

### What still needs execution evidence

- Actual delayed send delivery after timer.
- Strict mode behavior on uncertain FAQ query.
- Handoff and confirmation flows in live run.
- Integrations beyond core tools (YClients/Booking/VK/custom HTTP) require enabled connectors and scenario/tool exposure.

## Next update plan

After customer-side messages are sent, update this report with:

- Pass/fail matrix per scenario
- Timestamps and observed responses
- Defects and severity
- Improvement recommendations

## Immediate unblock checklist

1. Open Super Admin provider settings and ensure the configured `primary provider` has valid credentials and is active for Captain runtime.
2. If primary provider currently points to OpenAI, set valid `openai_api_key` (this is the concrete missing key shown in logs), or switch primary provider to another fully configured provider.
3. Re-run a smoke message in conversation `#2`: `Привет`.
4. Verify logs no longer contain `RubyLLM::ConfigurationError`.
5. Re-run reminder scenario message:
   - `Напомни мне через 3 минуты подтвердить запись.`
6. Confirm both:
   - immediate assistant confirmation without forced handoff
   - delayed follow-up message delivery after timer window.

## Task for Claude Opus 4.7

Goal: complete end-to-end manual validation of Captain after primary provider fix, with explicit proof for delayed follow-up delivery via `schedule_follow_up` + `NotificationTemplateDelivery`.

Context to use:
- Environment: `https://estbot.ru`, account `1`, conversation `#2`.
- Known blocker was provider configuration (`primary provider`), now expected to be fixed before test run.
- Existing report and historical evidence are in this file.

Execution requirements:
0. Capability check (mandatory before execution):
   - If browser/runtime access is available (browser MCP/Playwright + env logs/API), execute full E2E plan below.
   - If access is not available, do not fabricate evidence. Switch to `Runbook mode` and produce executable validation instructions for a human/operator with access.
1. Validate preconditions before tests:
   - Captain V2 path is active.
   - Primary provider is configured and no `RubyLLM::ConfigurationError` appears in fresh logs.
   - Background jobs/cron path for scheduled notifications is running (`TriggerScheduledItemsJob` -> `NotificationTemplates::ProcessScheduledJob`).
2. Run matrix `G1-G6` for delayed send flow:
   - success scheduling and delivery
   - invalid/edge delay values
   - delivery eligibility behavior
   - duplicate/retry safety where observable
3. Run enabled tool checks from scenario/tools config:
   - at least happy + error path for each enabled tool (`faq_lookup`, `schedule_follow_up`, `handoff`, and others enabled in runtime).
4. Run integration checklist `I1-I6` for available connectors:
   - include YClients and Notification Template webhook path as separate checks.
5. Optional: run Copilot CRUD checks for notification templates.

Runbook mode requirements (when direct execution is impossible):
- Build a step-by-step operator runbook for all required checks (preconditions, `G1-G6`, tools, `I1-I6`).
- For each test case provide:
  - exact command/API action to run (`curl`, `rails runner`, SQL/log query)
  - expected success and failure signals
  - exact log line pattern/regex to capture
  - evidence template fields: timestamp, actor, command, output snippet, verdict
- Provide a compact "two-hands protocol" where executor runs commands and pastes raw output, and analyst updates report strictly from observed outputs.

Output format (mandatory):
- Update this file with:
  - pass/fail table by test case
  - exact timestamps and observed assistant outputs
  - log evidence snippets for each failed case
  - root cause hypothesis per failure
  - severity and concrete fix recommendation
- If executed in `Runbook mode`, explicitly mark unexecuted cases as `NOT EXECUTED` (not failed), with reason `access/tooling limitation`.
- Add a final section `Release readiness` with verdict:
  - `Ready`, `Ready with caveats`, or `Not ready`
  - include top 3 risks that block production usage.

