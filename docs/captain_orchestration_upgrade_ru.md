# Captain Orchestration Upgrade (RU)

## Зачем это сделано

Цель изменений: перейти от модели "один большой промпт + набор тулов" к более предсказуемой оркестрации на базе `ai-agents`, где:

- чётко разделены **внутренние handoff между агентами** и **эскалация к человеку**;
- добавлены скрытые подагенты через `Agent#as_tool` для планирования/политики;
- ключевые tools возвращают структурированные данные, а не "магические" текстовые маркеры;
- состояние оркестрации и ожидаемые human interaction сохраняются как first-class runtime state;
- добавлены защиты от зацикливаний handoff и конкурентных запусков.

---

## Что изменено

### 1) `ai-agents`: handoff payload + loop guards

Файлы:

- `lib/agents/handoff.rb`
- `lib/agents/runner.rb`
- `spec/agents/handoff_spec.rb`
- `spec/agents/runner_spec.rb`

Что сделано:

- `HandoffTool` теперь принимает payload:
  - `handoff_reason`
  - `transfer_summary`
- `Runner` теперь:
  - сохраняет `handoff_trace`, `last_handoff`, `handoff_count` в `context`;
  - имеет лимит handoff (`DEFAULT_MAX_HANDOFFS`);
  - детектит повторяющийся цикл на одном и том же ребре (`MAX_REPEAT_HANDOFF_EDGE`);
  - выбрасывает `HandoffLoopError` и безопасно завершает run.

Зачем:

- для продовой устойчивости (anti-loop);
- для качественной передачи контекста специалисту (`transfer_summary`).

---

### 2) Семантика: handoff vs human escalation в Chatwoot

Файлы:

- `enterprise/lib/captain/tools/handoff_tool.rb`
- `enterprise/lib/captain/prompts/assistant.liquid`
- `enterprise/app/services/captain/assistant/autonomy_policy_helper.rb`
- `enterprise/app/services/captain/tools/search_reply_documentation_service.rb`
- `config/agents/tools.yml`

Что сделано:

- human tool переименован по имени функции в `escalate_to_human`;
- тексты, подсказки и policy-хинты переведены с `...--handoff` на `...--escalate_to_human`;
- в промптах зафиксирована строгая развилка:
  - `ask_human` = background approval/clarification;
  - `escalate_to_human` = last resort.

Зачем:

- убрать семантическую путаницу между "handoff внутри graph" и "передачей человеку".

---

### 3) Subagents-as-tools (`as_tool`) для planning/policy

Файлы:

- `enterprise/app/models/concerns/agentable.rb`
- `enterprise/app/models/captain/assistant.rb`
- `enterprise/app/models/captain/scenario.rb`

Что сделано:

- в `Agentable` добавлены скрытые subagent tools:
  - `plan_next_step`
  - `check_response_policy`
- оба строятся через `Agents::Agent.new(...).as_tool(...)`;
- эти tools подключены в `assistant` и `scenario` агентам;
- добавлены structured schema для планирования/политики;
- в системные инструкции добавляется `Agents::RECOMMENDED_HANDOFF_PROMPT_PREFIX`.

Зачем:

- разгрузить main-agent;
- сделать маршрутизацию и policy-решения более стабильными.

---

### 4) Структурированные tool-ответы и shared memory

Файлы:

- `enterprise/lib/captain/tools/faq_lookup_tool.rb`
- `enterprise/lib/captain/tools/http_tool.rb`
- `enterprise/lib/captain/response_schema.rb`
- `enterprise/lib/captain/prompts/assistant.liquid`

Что сделано:

- `FaqLookupTool` теперь возвращает hash-структуру вида:
  - `status`, `policy`, `answer_draft`, `sources`, `requires_operator`, `confidence`;
- результат FAQ записывается в `tool_context.state[:orchestration][:last_faq_lookup]`;
- `HttpTool` теперь возвращает структуру:
  - `status`, `data`, `user_safe_summary`, `retryable`;
- его результат тоже сохраняется в orchestration state;
- response schema расширена полем `status`;
- промпт ориентирован на `policy`/`answer_draft`, а не на парсинг строки.

Зачем:

- сократить хрупкий parsing текста;
- сделать tool orchestration машинно-детерминированной.

---

### 5) Suspend/Resume основа для `ask_human`

Файлы:

- `enterprise/lib/captain/tools/ask_human_tool.rb`
- `app/services/approval_bot/action_executor_service.rb`
- `enterprise/app/services/captain/assistant/autonomy_policy_helper.rb`

Что сделано:

- `ask_human` теперь возвращает структурированный ответ со статусом `awaiting_human` и `interaction_id`;
- pending-interaction сохраняется в runtime state (`pending_human_interaction`);
- при `resume_captain` сохраняется `last_human_response` + `freshness` (stale-check на количество сообщений);
- `AutonomyPolicyHelper` прокидывает в context:
  - `pending_human_interaction`
  - `pending_human_interaction_stale`
  - `last_human_response`

Зачем:

- перейти от "неявного продолжения" к явной state-machine модели `awaiting -> resume`.

---

### 6) Persisted orchestration state + callbacks + concurrency lock

Файлы:

- `enterprise/app/services/captain/assistant/agent_runner_service.rb`
- `enterprise/app/jobs/captain/conversation/response_builder_job.rb`
- `enterprise/app/services/captain/scenario_router_service.rb`
- `enterprise/lib/captain/prompts/scenario.liquid`

Что сделано:

- добавлен lock на conversation run (`Redis::LockManager`) чтобы избежать параллельных конфликтных запусков;
- добавлен `busy`-ответ при невозможности взять lock;
- после tool/handoff/run события пишутся:
  - приватные internal notes в conversation;
  - runtime orchestration state (`current_agent`, `handoff_trace`, `last_handoff`, `last_faq_lookup`, `last_http_tool_result`, pending interaction и т.д.);
- `ResponseBuilderJob` теперь корректно пропускает отправку в канал, если:
  - `awaiting_human`
  - `busy`
  - пустой `response`;
- `ScenarioRouterService` расширен `routing_plan` (route/confidence/hint) как shortcut-гейт;
- в промпты assistant/scenario добавлен вывод handoff summary/reason + orchestration state.

Зачем:

- повысить наблюдаемость и управляемость;
- снизить риск race conditions;
- сделать resumable orchestration более предсказуемой.

---

## Что и как тестировать

## Автоматические проверки

### `ai-agents` (прошли)

```bash
RBENV_VERSION=3.4.4 bundle exec rspec spec/agents/handoff_spec.rb spec/agents/runner_spec.rb spec/agents/agent_tool_spec.rb
```

Результат: **74 examples, 0 failures**.

### `chatwoot` (блокер окружения)

Запуск целевых spec-файлов:

```bash
bundle exec rspec spec/enterprise/services/captain/assistant/agent_runner_service_spec.rb spec/enterprise/lib/captain/tools/faq_lookup_tool_spec.rb spec/enterprise/lib/captain/tools/ask_human_tool_spec.rb
```

Текущий блокер: недоступен test PostgreSQL (`PG::ConnectionBad`, host `91.186.196.38:5432`, connection refused).

---

## Ручной тест-план (обязательно)

1. **FAQ happy path**
   - пользователь задаёт FAQ-вопрос;
   - `faq_lookup` возвращает `policy: answer`;
   - ответ уходит пользователю из `answer_draft`;
   - эскалации нет.

2. **FAQ c operator clarification**
   - `faq_lookup` возвращает `policy: ask_human` / `requires_operator: true`;
   - вызывается `ask_human`;
   - в канал не отправляется финальный ответ (`awaiting_human`);
   - создаётся pending approval request + runtime state.

3. **Resume после ответа оператора**
   - оператор отвечает через Approval flow (`resume_captain`);
   - появляется `last_human_response` в runtime state;
   - проверяется `freshness` (stale true/false).

4. **Human escalation**
   - кейс, когда нужен live agent;
   - вызывается `escalate_to_human`;
   - формируется понятный internal note;
   - conversation переводится на человека.

5. **Scenario routing + handoff payload**
   - вопрос уводит в scenario;
   - проверяем `handoff_trace`, `last_handoff`, `transfer_summary` в context/state;
   - сценарий получает summary в prompt context.

6. **Concurrency**
   - быстро отправить несколько сообщений в один conversation;
   - убедиться, что второй run не ломает состояние (lock/busy path).

7. **Loop guard**
   - смоделировать повторное перекладывание между одними и теми же агентами;
   - убедиться, что run останавливается по loop guard.

---

## Ключевые риски / что мониторить после релиза

- доля ответов со статусом `busy` (признак lock contention);
- частота `awaiting_human` и время до резолюции;
- частота `HandoffLoopError`;
- доля эскалаций к человеку;
- latency сценариев с subagents (`plan_next_step`, `check_response_policy`);
- корректность private notes (не должно быть лишнего шума в high-load).

---

## Кратко для коллег

Это не "косметический рефактор". Мы перевели Captain V2 в сторону реальной multi-agent orchestration:

- сильнее опираемся на `ai-agents` механики;
- нормализуем контракты tools и состояние;
- отделяем внутреннюю маршрутизацию от human escalation;
- готовим систему к устойчивому suspend/resume и high-load эксплуатации.

