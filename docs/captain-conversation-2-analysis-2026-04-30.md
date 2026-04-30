Нужен ресерч по проблеме tool calling в Captain (Chatwoot) в формате ФР/ОР, с анализом на уровне фреймворка, который исполняет tools.

## Контекст

Мы используем multi-agent runtime (Ruby Agents SDK style), где tools объявляются в системном контексте и передаются в раннер.  
Ожидание: для фактических FAQ-вопросов ассистент делает реальный tool-call (`captain--tools--faq_lookup`) и только потом отвечает пользователю.

---

## ФР (Фактический результат)

### Сценарий
Пользователь:  
`Привет! Ответь сразу по FAQ без фраз "сейчас проверю" — есть ли бесплатная парковка?`

### Что реально произошло
1. Роутинг: `direct`
2. Ассистент вернул текстовый ответ-процесс:
   - `Проверяю информацию в базе знаний.`
3. Ответ был принят как валидный (`acceptable=true`) и отправлен пользователю.
4. Признаков реального вызова FAQ tool нет:
   - `faq_called=` пусто
   - `faq_lookup_called=` пусто
   - `last_faq_lookup=nil`
5. В reasoning модель пишет, что нужно вызвать FAQ tool, но tool-call фактически не происходит.

### Логи (ключевые строки)
```text
[Captain LLM prompt] ... conversation_id=610 ... model=deepseek/deepseek-v3.2 payload=[system,user]
[Captain V2] orchestrator_routing_decision=direct conversation_length_at_routing=1
[Captain DEBUG TMP] runner.run outcome label=attempt_0 acceptable=true response_preview="Проверяю информацию в базе знаний." current_agent="" faq_called= error=:
[Captain V2] Agent result: output={"reasoning"=>"...Нужно проверить FAQ, затем дать прямой ответ.","response"=>"Проверяю информацию в базе знаний."}
[Captain DEBUG TMP] process_agent_result current_agent="" response_preview="Проверяю информацию в базе знаний." faq_lookup_called=
[conversation.updated] assistant_runtime={... "last_routing_decision"=>"direct", "last_faq_lookup"=>nil ...}
```

---

## ОР (Ожидаемый результат)

Для такого вопроса система должна:
1. Сделать реальный вызов `captain--tools--faq_lookup`.
2. Получить tool result.
3. Сформировать финальный ответ на основе tool result (или корректно эскалировать, если policy требует).
4. Не отправлять промежуточные фразы (`Проверяю...`, `Сейчас уточню...`) как финальный пользовательский ответ.

Ожидаемые признаки в логах:
- `on_tool_complete tool_name="captain--tools--faq_lookup"...`
- `faq_called=true` / `faq_lookup_called=true`
- `assistant_runtime.last_faq_lookup != nil`
- финальный ответ содержит фактический FAQ-result, а не процессный статус.

---

## Что нужно проресерчить

Исследование нужно провести в рамках фреймворка tool calling (не только промпт).

### Вопрос 1: Почему при наличии tools в контексте tool-call не происходит?
- Где именно в фреймворке принимается решение:
  - вернуть plain assistant text
  - или сделать function/tool call?
- Является ли это ожидаемым поведением текущего SDK/модели (deepseek), когда tool use не enforced?

### Вопрос 2: Почему ответ без tool-call проходит `acceptable=true`?
- Проанализировать acceptance policy и место, где “непустой текст” считается достаточным.
- Нужно ли ввести обязательный guard “tool-required-before-accept” для FAQ-like factual запросов?

### Вопрос 3: Если tools уже передаются фреймворком, зачем мы отдельно описываем tools в system prompt?
- Что реально дает текстовое описание tools поверх schema-level tool registration?
- Где граница ответственности:
  - prompt (инструкция/предпочтение),
  - framework/runtime (фактическое исполнение),
  - policy layer (accept/reject и retries)?
- Какой минимальный контракт нужен в prompt, если enforcement делаем в рантайме?

### Вопрос 4: Как правильно спроектировать enforcement без регрессий?
- Reject process-фраз без tool-call.
- Retry с жесткой подсказкой “сначала вызови faq_lookup”.
- Избежать циклов и чрезмерного блокирования валидных direct-ответов.
- Добавить observability, чтобы в UI было видно: “почему accepted/rejected”.

---

## Ожидаемый результат ресерча

Дай практичный engineering proposal:
1. Root cause по слоям (model/framework/policy/prompt).
2. Точное место фикса (файлы/методы).
3. Предложение runtime guard (псевдокод).
4. Роль prompt после внедрения guard.
5. План валидации (manual + automated).
6. Риски и rollout-план (feature flag, метрики).