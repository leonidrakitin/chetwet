# Captain: ApprovalRequest без обязательного Telegram

## Контекст

- `Captain::Tools::HandoffTool#notify_operator_via_telegram`: при отсутствии пользователя с `telegram_chat_id` возвращает `nil` → `**Captain::ApprovalRequest` не создаётся** → сообщение клиенту без `approval_request_id`, в дашборде не работают кнопки выбора (`Form.vue`).
- Если заявка создана → `ApprovalBot::NotifyJob` шлёт в мессенджеры тем, кто в `target_users` и доступен боту.
- Ориентиры: `enterprise/lib/captain/tools/handoff_tool.rb`, модель `Captain::ApprovalRequest`, Approval Bot dispatch, контроллер `captain/approval_requests`, UI `Form.vue`, `useCopilotReply.js`.

## Задание

1. **Разделить** создание `Captain::ApprovalRequest` и отправку уведомлений: заявку создавать **независимо от наличия Telegram**; Telegram/VK/MAX — опционально.
2. Добавить **настройку** (assistant или account): если включено — при **любом** `escalate_to_human` **всегда** создаётся `ApprovalRequest` с текущими `options` (аргументы LLM → fallback из FAQ → «Предложить свой вариант» через `build_options`).
3. **Клиенту** — только текст (напр. «Уточняю детали»), через i18n; **не** слать клиенту `input_select` с вариантами оператора.
4. **Связь заявки с UI дашборда** без операторских кнопок в канале клиента (приватная заметка / activity / минимально иной канал связи по `conversation` — подобрать наименьшее вторжение в код).
5. `**decision_maker_ids` не использовать.** `assignee` заявки и таргеты уведомлений согласовать с **фактической логикой handoff назначения** после `bot_handoff!`; заменить `resolve_notification_target` на решение без `decision_maker_ids`.
6. Уведомления: допускается рассылка «ширше» конфигурации ботов; **нет** нового продукотового экрана «ожидающие согласования».
7. **Гонки:** кто первый разрешил — тот главный; уже `resolved` — идемпотентно (как PATCH сейчас); без двойной отправки клиенту из двух источников.
8. **Оператор:** выбор варианта → `**generate_draft`** → доработка → отправка; унифицировать дашборд и callback из Telegram там, где уместно.
9. **Тесты:** эскалация без TG у assignee — заявка есть, клиенту без `input_select`; с TG — та же заявка + доп. уведомление.

